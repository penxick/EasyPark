import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AdminPageDto, pageResult } from './admin-query.dto';

// Match USER freeSpaces and Flutter displayStatus, without counting a slot twice.
const spaceCounts = `COUNT(*)::int AS "totalSpaces",
  COUNT(*) FILTER (WHERE status = 'FREE' AND NOT "physicalOccupied")::int AS "freeSpaces",
  COUNT(*) FILTER (WHERE status = 'OCCUPIED' OR (status = 'FREE' AND "physicalOccupied"))::int AS "occupiedSpaces",
  COUNT(*) FILTER (WHERE status = 'RESERVED')::int AS "reservedSpaces",
  COUNT(*) FILTER (WHERE status = 'UNAVAILABLE')::int AS "unavailableSpaces",
  COUNT(*) FILTER (WHERE "physicalOccupied")::int AS "physicalOccupiedSpaces"`;

interface SpaceCounts {
  totalSpaces: number;
  freeSpaces: number;
  occupiedSpaces: number;
  reservedSpaces: number;
  unavailableSpaces: number;
  physicalOccupiedSpaces: number;
}
interface Summary extends SpaceCounts {
  totalParkings: number;
  totalUsers: number;
  totalReservations: number;
  activeReservations: number;
}
interface ParkingAnalytics extends SpaceCounts {
  id: number;
  name: string;
  totalReservations: number;
  activeReservations: number;
}

function withOccupancy<T extends SpaceCounts>(counts: T) {
  const available = counts.totalSpaces - counts.unavailableSpaces;
  return {
    ...counts,
    occupancyPercent:
      available === 0
        ? 0
        : Math.round(
            (10000 * (counts.occupiedSpaces + counts.reservedSpaces)) /
              available,
          ) / 100,
  };
}

@Injectable()
export class AdminAnalyticsService {
  constructor(private readonly db: DataSource) {}

  async summary() {
    const rows: Summary[] = await this.db.query(`
      SELECT spaces.*,
        (SELECT COUNT(*)::int FROM parkings) AS "totalParkings",
        (SELECT COUNT(*)::int FROM users) AS "totalUsers",
        (SELECT COUNT(*)::int FROM reservations) AS "totalReservations",
        (SELECT COUNT(*)::int FROM reservations WHERE status IN ('ACTIVE', 'PENDING')
          AND "endTime" > CURRENT_TIMESTAMP) AS "activeReservations"
      FROM (SELECT ${spaceCounts} FROM parking_spaces) spaces`);
    return withOccupancy(rows[0]);
  }

  async parkings(query: AdminPageDto) {
    return this.db.transaction('REPEATABLE READ', async (manager) => {
      const [{ total }]: { total: number }[] = await manager.query(
        'SELECT COUNT(*)::int AS total FROM parkings',
      );
      const rows: ParkingAnalytics[] = await manager.query(
        `
        WITH space_counts AS (
          SELECT "parkingId", ${spaceCounts} FROM parking_spaces GROUP BY "parkingId"
        ), reservation_counts AS (
          SELECT space."parkingId", COUNT(*)::int AS "totalReservations",
            COUNT(*) FILTER (WHERE reservation.status IN ('ACTIVE', 'PENDING')
              AND reservation."endTime" > CURRENT_TIMESTAMP)::int AS "activeReservations"
          FROM reservations reservation JOIN parking_spaces space ON space.id = reservation."parkingSpaceId"
          GROUP BY space."parkingId"
        )
        SELECT parking.id, parking.name,
          COALESCE(spaces."totalSpaces", 0) AS "totalSpaces",
          COALESCE(spaces."freeSpaces", 0) AS "freeSpaces",
          COALESCE(spaces."occupiedSpaces", 0) AS "occupiedSpaces",
          COALESCE(spaces."reservedSpaces", 0) AS "reservedSpaces",
          COALESCE(spaces."unavailableSpaces", 0) AS "unavailableSpaces",
          COALESCE(spaces."physicalOccupiedSpaces", 0) AS "physicalOccupiedSpaces",
          COALESCE(reservations."totalReservations", 0) AS "totalReservations",
          COALESCE(reservations."activeReservations", 0) AS "activeReservations"
        FROM parkings parking
        LEFT JOIN space_counts spaces ON spaces."parkingId" = parking.id
        LEFT JOIN reservation_counts reservations ON reservations."parkingId" = parking.id
        ORDER BY parking.id ASC LIMIT $1 OFFSET $2`,
        [query.pageSize, (query.page - 1) * query.pageSize],
      );
      return pageResult(rows.map(withOccupancy), total, query);
    });
  }
}
