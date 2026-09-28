# Feature boundaries

Auth is implemented in stage 5: controller, repository, models and adaptive forms.
MainShell has three StatefulShellRoute branches and preserves their state.
Stage 8 implements MapScreen with ParkingRepository, validated Parking data,
FlutterMap markers, load/error/empty states and the ParkingSummary modal.
The repository borrows AuthRepository.api; AuthController owns its lifecycle.
Business HTTP requests use ApiClient and JWT. Map tiles use flutter_map's separate
network provider and built-in cache, without credentials or business data.
Stage 15 implements ProfileScreen using AuthRepository.me(): name, email and
registration date. Logout deletes the secure token and clears the current identity.
If deletion fails, session retry continues logout instead of restoring that token.
Profile editing and vehicle fields remain outside the implemented scope.
Stage 9 adds ParkingDetailsScreen and a validated ParkingDetails model. Details are fetched by ID; missing counts remain unknown, never fabricated.
Stage 11 adds ParkingLayoutScreen, ParkingSpacesRepository and the ParkingSpace
model. Native widgets render API coordinates and four statuses. Only effectively
free spaces can be selected.
Stage 13 adds BookingScreen, ReservationRepository, a validated Reservation model,
and ReservationCard with confirmed cancellation. ReservationsScreen restores active
bookings from the API. Uncertain POST results require reconciliation with GET /me
before a retry. The layout reloads when returning from booking.
Stage 14 adds active/completed/cancelled history categories. PENDING is active;
EXPIRED is completed with its original status label. Confirmed cancellation moves
the card immediately. LoadController handles failures and stale responses.
No payment UI or simulated payment is implemented.
Add other feature repositories and business UI only at their specified stages.

