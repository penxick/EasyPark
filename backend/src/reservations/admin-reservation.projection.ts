import { EntityManager } from 'typeorm';
import { Reservation, ReservationStatus } from './reservation.entity';

// Read-only effective status avoids stale ACTIVE rows between worker passes.
export const adminReservationStatus = `CASE
  WHEN reservation.mode IS NULL AND reservation.status = 'ACTIVE' AND reservation.endTime <= :now THEN 'COMPLETED'
  WHEN reservation.mode IS NULL AND reservation.status = 'PENDING' AND reservation.endTime <= :now THEN 'EXPIRED'
  ELSE reservation.status END`;

export function adminReservationQuery(manager: EntityManager, now: Date) {
  return manager
    .getRepository(Reservation)
    .createQueryBuilder('reservation')
    .innerJoin('reservation.user', 'user')
    .innerJoin('reservation.parkingSpace', 'space')
    .innerJoin('space.parking', 'parking')
    .select('reservation.id', 'id')
    .addSelect('reservation.createdAt', 'createdAt')
    .addSelect('reservation.startTime', 'startTime')
    .addSelect('reservation.endTime', 'endTime')
    .addSelect('reservation.totalPrice', 'totalPrice')
    .addSelect(adminReservationStatus, 'status')
    .addSelect('user.id', 'userId')
    .addSelect('user.name', 'userName')
    .addSelect('user.email', 'userEmail')
    .addSelect('parking.id', 'parkingId')
    .addSelect('parking.name', 'parkingName')
    .addSelect('parking.address', 'parkingAddress')
    .addSelect('space.id', 'spaceId')
    .addSelect('space.code', 'spaceCode')
    .setParameter('now', now);
}

export interface AdminReservationRow {
  id: number;
  createdAt: Date;
  startTime: Date;
  endTime: Date;
  totalPrice: string;
  status: ReservationStatus;
  userId: number;
  userName: string;
  userEmail: string;
  parkingId: number;
  parkingName: string;
  parkingAddress: string;
  spaceId: number;
  spaceCode: string;
}

export function adminReservation(row: AdminReservationRow) {
  return {
    id: row.id,
    createdAt: row.createdAt,
    startTime: row.startTime,
    endTime: row.endTime,
    status: row.status,
    totalPrice: Number(row.totalPrice),
    user: { id: row.userId, name: row.userName, email: row.userEmail },
    parking: {
      id: row.parkingId,
      name: row.parkingName,
      address: row.parkingAddress,
    },
    space: { id: row.spaceId, code: row.spaceCode },
  };
}
