import { DataSource } from 'typeorm';
import { Parking } from '../parking/parking.entity';
import {
  ParkingSpace,
  ParkingSpaceStatus,
} from '../parking-spaces/parking-space.entity';
import { demoParkings } from './parking-seed';

// Logical layout coordinates in a 600 x 350 canvas, inspired by the Figma reference.
// Polygons are reserved for a later calibrated camera coordinate system.
export const demoSpaces = ['A', 'B', 'C', 'D'].flatMap((zone, column) =>
  Array.from({ length: 5 }, (_, row) => {
    const status =
      zone === 'D' && row === 4
        ? ParkingSpaceStatus.UNAVAILABLE
        : row === 1
          ? ParkingSpaceStatus.OCCUPIED
          : row === 3
            ? ParkingSpaceStatus.RESERVED
            : ParkingSpaceStatus.FREE;
    return {
      code: `${zone}${String(row + 1).padStart(2, '0')}`,
      status,
      physicalOccupied: status === ParkingSpaceStatus.OCCUPIED,
      x: [50, 150, 370, 470][column],
      y: 50 + row * 50,
      polygon: null,
    };
  }),
);

export async function seedParkingSpaces(db: DataSource): Promise<number> {
  return db.transaction(async (manager) => {
    await manager.query('SELECT pg_advisory_xact_lock(714208)');
    let inserted = 0;
    for (const fixture of demoParkings) {
      const parking = await manager.getRepository(Parking).findOne({
        where: { name: fixture.name, address: fixture.address },
        order: { id: 'ASC' },
      });
      if (!parking) throw new Error('Seed demo parkings before spaces.');
      const result = await manager
        .getRepository(ParkingSpace)
        .createQueryBuilder()
        .insert()
        .values(
          demoSpaces.map((space) => ({ ...space, parkingId: parking.id })),
        )
        .orIgnore()
        .returning('id')
        .execute();
      inserted += (result.raw as unknown[]).length;
    }
    return inserted;
  });
}
