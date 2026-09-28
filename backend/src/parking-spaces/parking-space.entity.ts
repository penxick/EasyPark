import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Parking } from '../parking/parking.entity';

export enum ParkingSpaceStatus {
  FREE = 'FREE',
  OCCUPIED = 'OCCUPIED',
  RESERVED = 'RESERVED',
  UNAVAILABLE = 'UNAVAILABLE',
}

@Entity('parking_spaces')
@Index('UQ_parking_spaces_code', ['parkingId', 'code'], { unique: true })
@Check(
  'CHK_parking_spaces_status',
  `"status" IN ('FREE', 'OCCUPIED', 'RESERVED', 'UNAVAILABLE')`,
)
@Check(
  'CHK_parking_spaces_code',
  `"code" = btrim("code") AND length("code") > 0`,
)
@Check('CHK_parking_spaces_x', '"x" >= 0 AND "x" < \'Infinity\'::float8')
@Check('CHK_parking_spaces_y', '"y" >= 0 AND "y" < \'Infinity\'::float8')
@Check(
  'CHK_parking_spaces_polygon',
  `"polygon" IS NULL OR (jsonb_typeof("polygon") = 'array' AND jsonb_array_length("polygon") >= 3)`,
)
export class ParkingSpace {
  @PrimaryGeneratedColumn({ primaryKeyConstraintName: 'PK_parking_spaces_id' })
  id!: number;
  @Column({ type: 'integer' }) parkingId!: number;
  @ManyToOne(() => Parking, { onDelete: 'RESTRICT', nullable: false })
  @JoinColumn({
    name: 'parkingId',
    foreignKeyConstraintName: 'FK_parking_spaces_parking',
  })
  parking!: Parking;
  @Column({ type: 'varchar', length: 20 }) code!: string;
  @Column({ type: 'varchar', length: 11, default: ParkingSpaceStatus.FREE })
  status!: ParkingSpaceStatus;
  @Column({ type: 'boolean', default: false }) physicalOccupied!: boolean;
  @Column({ type: 'double precision' }) x!: number;
  @Column({ type: 'double precision' }) y!: number;
  @Column({ type: 'jsonb', nullable: true }) polygon!:
    [number, number][] | null;
  @CreateDateColumn({ type: 'timestamptz' }) createdAt!: Date;
  @UpdateDateColumn({ type: 'timestamptz' }) updatedAt!: Date;
}
