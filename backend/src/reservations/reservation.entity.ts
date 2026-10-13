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
@Check('CHK_session_fields', `mode IS NULL OR (
        mode IN ('PLANNED','METERED') AND "sessionState" IS NOT NULL AND
        "sessionState" IN ('WAITING_ARRIVAL','PARKED','WAITING_DEPARTURE','FINISHED','CANCELLED') AND
        "paymentMethod" IS NOT NULL AND "paymentMethod" IN ('CARD','SBP') AND
        "paymentStatus" IS NOT NULL AND "paymentStatus" IN ('DEMO_PENDING','DEMO_CONFIRMED') AND
        "hourlyRateSnapshot" IS NOT NULL AND "hourlyRateSnapshot" >= 0 AND
        ((mode='PLANNED' AND "plannedMinutes" BETWEEN 1 AND 1440 AND "preliminaryPrice" >= 0)
         OR (mode='METERED' AND "plannedMinutes" IS NULL AND "preliminaryPrice" IS NULL))
      )`)
@Check('CHK_session_actual', `("actualSeconds" IS NULL OR "actualSeconds" >= 0) AND
        ("finalPrice" IS NULL OR "finalPrice" >= 0) AND
        ("actualEndTime" IS NULL OR ("actualStartTime" IS NOT NULL AND "actualEndTime" >= "actualStartTime"))`)
export class Reservation {
  @Column({ type: 'varchar', length: 7, nullable: true }) mode!:
    'PLANNED' | 'METERED' | null;
  @Column({ type: 'varchar', length: 20, nullable: true }) sessionState!:
    | 'WAITING_ARRIVAL'
    | 'PARKED'
    | 'WAITING_DEPARTURE'
    | 'FINISHED'
    | 'CANCELLED'
    | null;
  @Column({ type: 'varchar', length: 4, nullable: true }) paymentMethod!:
    'CARD' | 'SBP' | null;
  @Column({ type: 'varchar', length: 20, nullable: true }) paymentStatus!:
    'DEMO_CONFIRMED' | 'DEMO_PENDING' | null;
  @Column({ type: 'integer', nullable: true }) plannedMinutes!: number | null;
  @Column({ type: 'numeric', precision: 10, scale: 2, nullable: true })
  hourlyRateSnapshot!: string | null;
  @Column({ type: 'numeric', precision: 12, scale: 2, nullable: true })
  preliminaryPrice!: string | null;
  @Column({ type: 'numeric', precision: 12, scale: 2, nullable: true })
  finalPrice!: string | null;
  @Column({ type: 'timestamptz', nullable: true })
  actualStartTime!: Date | null;
  @Column({ type: 'timestamptz', nullable: true }) actualEndTime!: Date | null;
  @Column({ type: 'integer', nullable: true }) actualSeconds!: number | null;
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
      to: (value: number | string) => value,
      from: (value: string) => Number(value),
    },
  })
  totalPrice!: number | string;
  @CreateDateColumn({ type: 'timestamptz' }) createdAt!: Date;
  @UpdateDateColumn({ type: 'timestamptz' }) updatedAt!: Date;
}
