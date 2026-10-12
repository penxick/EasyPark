import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

const decimalNumber = {
  to: (value: number) => value,
  from: (value: string) => Number(value),
};

@Entity('parkings')
@Check(
  'CHK_parkings_price30',
  '"pricePer30Min" >= 0 AND "pricePer30Min" <= 99999999.99',
)
@Check('CHK_parkings_latitude', '"latitude" BETWEEN -90 AND 90')
@Check('CHK_parkings_longitude', '"longitude" BETWEEN -180 AND 180')
@Check(
  'CHK_parkings_price',
  '"pricePerHour" >= 0 AND "pricePerHour" <= 99999999.99',
)
export class Parking {
  @PrimaryGeneratedColumn({ primaryKeyConstraintName: 'PK_parkings_id' })
  id!: number;
  @Column({ type: 'varchar', length: 200 })
  name!: string;
  @Column({ type: 'text' })
  description!: string;
  @Column({ type: 'varchar', length: 500 })
  address!: string;
  @Column({
    type: 'numeric',
    precision: 9,
    scale: 6,
    transformer: decimalNumber,
  })
  latitude!: number;
  @Column({
    type: 'numeric',
    precision: 9,
    scale: 6,
    transformer: decimalNumber,
  })
  longitude!: number;
  @Column({
    type: 'numeric',
    precision: 10,
    scale: 2,
    transformer: decimalNumber,
  })
  pricePerHour!: number;
  @Column({ type: 'numeric', precision: 10, scale: 2, default: 0 })
  pricePer30Min!: string;
  @Column({ type: 'varchar', length: 200 })
  workingHours!: string;
  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;
  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;
}
