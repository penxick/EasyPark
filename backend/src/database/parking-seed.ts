import { DataSource } from 'typeorm';
import { Parking } from '../parking/parking.entity';

// Fictional development fixtures, not real parking availability or tariffs.
export const demoParkings = [
  {
    name: 'Демо — Центральная',
    description: 'Тестовая парковка EasyPark.',
    address: 'Красноярск, учебная точка Центр',
    latitude: 56.010563,
    longitude: 92.852572,
    pricePerHour: 100,
    workingHours: 'Круглосуточно',
  },
  {
    name: 'Демо — Северная',
    description: 'Тестовая парковка EasyPark.',
    address: 'Красноярск, учебная точка Север',
    latitude: 56.045,
    longitude: 92.905,
    pricePerHour: 80,
    workingHours: '08:00–22:00',
  },
  {
    name: 'Демо — Набережная',
    description: 'Тестовая парковка EasyPark.',
    address: 'Красноярск, учебная точка Набережная',
    latitude: 56.005,
    longitude: 92.87,
    pricePerHour: 120.5,
    workingHours: 'Круглосуточно',
  },
];

export async function seedParkings(db: DataSource): Promise<number> {
  return db.transaction(async (manager) => {
    // Serialize concurrent seed runs without adding a business uniqueness rule.
    await manager.query('SELECT pg_advisory_xact_lock(714207)');
    const repository = manager.getRepository(Parking);
    let inserted = 0;
    for (const parking of demoParkings) {
      if (
        await repository.existsBy({
          name: parking.name,
          address: parking.address,
        })
      )
        continue;
      await repository.save(repository.create(parking));
      inserted++;
    }
    return inserted;
  });
}
