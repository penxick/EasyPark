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
import { User } from '../users/user.entity';
import { ParkingSpace } from '../parking-spaces/parking-space.entity';

export enum ReservationStatus {
  PENDING = 'PENDING',
  ACTIVE = 'ACTIVE',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
  EXPIRED = 'EXPIRED',
}

@Entity('reservations')
@Index('UQ_reservations_live_space', ['parkingSpaceId'], {
  unique: true,
  where: `"status" IN ('PENDING', 'ACTIVE')`,
})
@Index('IDX_reservations_user', ['userId'])
@Index('IDX_reservations_expiry', ['endTime'], {
  where: `"status" IN ('PENDING', 'ACTIVE')`,
})
@Check(
  'CHK_reservations_status',
  `"status" IN ('PENDING', 'ACTIVE', 'COMPLETED', 'CANCELLED', 'EXPIRED')`,
)
@Check(
  'CHK_reservations_time',
  `isfinite("startTime") AND isfinite("endTime") AND "endTime" > "startTime"`,
)
@Check(
  'CHK_reservations_price',
  '"totalPrice" >= 0 AND "totalPrice" <= 9999999999.99',
)
export class Reservation {
  @PrimaryGeneratedColumn({ primaryKeyConstraintName: 'PK_reservations_id' })
  id!: number;
  @Column({ type: 'integer' }) userId!: number;
  @ManyToOne(() => User, { onDelete: 'RESTRICT', nullable: false })
  @JoinColumn({
    name: 'userId',
    foreignKeyConstraintName: 'FK_reservations_user',
  })
  user!: User;
  @Column({ type: 'integer' }) parkingSpaceId!: number;
  @ManyToOne(() => ParkingSpace, { onDelete: 'RESTRICT', nullable: false })
  @JoinColumn({
    name: 'parkingSpaceId',
    foreignKeyConstraintName: 'FK_reservations_space',
  })
  parkingSpace!: ParkingSpace;
  @Column({ type: 'timestamptz' }) startTime!: Date;
  @Column({ type: 'timestamptz' }) endTime!: Date;
  @Column({ type: 'varchar', length: 9, default: ReservationStatus.ACTIVE })
  status!: ReservationStatus;
  @Column({
    type: 'numeric',
    precision: 12,
    scale: 2,
    transformer: {
      to: (value: number) => value,
      from: (value: string) => Number(value),
    },
  })
  totalPrice!: number;
  @CreateDateColumn({ type: 'timestamptz' }) createdAt!: Date;
  @UpdateDateColumn({ type: 'timestamptz' }) updatedAt!: Date;
}
