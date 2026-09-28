import { useState } from 'react';
import { ParkingMap } from './ParkingMap';
import { ParkingList } from './ParkingList';
import { BookingDialog } from './BookingDialog';
import { DriverProfile, UserProfile } from './DriverProfile';
import { Button } from './ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs';
import { ArrowLeft, Map, List, User, MapPin } from 'lucide-react';

interface DriverAppProps {
  onBack: () => void;
  userProfile?: UserProfile;
  onProfileUpdate?: (profile: UserProfile) => void;
}

export interface ParkingSpot {
  id: string;
  number: string;
  status: 'free' | 'occupied' | 'reserved';
  x: number;
  y: number;
  width: number;
  height: number;
  price: number;
  zone: string;
}

const mockParkingSpots: ParkingSpot[] = [
  // Зона A
  { id: '1', number: 'A-1', status: 'free', x: 50, y: 50, width: 80, height: 40, price: 100, zone: 'A' },
  { id: '2', number: 'A-2', status: 'occupied', x: 50, y: 100, width: 80, height: 40, price: 100, zone: 'A' },
  { id: '3', number: 'A-3', status: 'free', x: 50, y: 150, width: 80, height: 40, price: 100, zone: 'A' },
  { id: '4', number: 'A-4', status: 'free', x: 50, y: 200, width: 80, height: 40, price: 100, zone: 'A' },
  { id: '5', number: 'A-5', status: 'occupied', x: 50, y: 250, width: 80, height: 40, price: 100, zone: 'A' },
  
  // Зона B
  { id: '6', number: 'B-1', status: 'free', x: 150, y: 50, width: 80, height: 40, price: 80, zone: 'B' },
  { id: '7', number: 'B-2', status: 'free', x: 150, y: 100, width: 80, height: 40, price: 80, zone: 'B' },
  { id: '8', number: 'B-3', status: 'occupied', x: 150, y: 150, width: 80, height: 40, price: 80, zone: 'B' },
  { id: '9', number: 'B-4', status: 'free', x: 150, y: 200, width: 80, height: 40, price: 80, zone: 'B' },
  { id: '10', number: 'B-5', status: 'free', x: 150, y: 250, width: 80, height: 40, price: 80, zone: 'B' },
  
  // Зона C (правая сторона)
  { id: '11', number: 'C-1', status: 'occupied', x: 370, y: 50, width: 80, height: 40, price: 120, zone: 'C' },
  { id: '12', number: 'C-2', status: 'free', x: 370, y: 100, width: 80, height: 40, price: 120, zone: 'C' },
  { id: '13', number: 'C-3', status: 'free', x: 370, y: 150, width: 80, height: 40, price: 120, zone: 'C' },
  { id: '14', number: 'C-4', status: 'occupied', x: 370, y: 200, width: 80, height: 40, price: 120, zone: 'C' },
  { id: '15', number: 'C-5', status: 'free', x: 370, y: 250, width: 80, height: 40, price: 120, zone: 'C' },
  
  // Зона D (правая сторона)
  { id: '16', number: 'D-1', status: 'free', x: 470, y: 50, width: 80, height: 40, price: 120, zone: 'D' },
  { id: '17', number: 'D-2', status: 'free', x: 470, y: 100, width: 80, height: 40, price: 120, zone: 'D' },
  { id: '18', number: 'D-3', status: 'occupied', x: 470, y: 150, width: 80, height: 40, price: 120, zone: 'D' },
  { id: '19', number: 'D-4', status: 'free', x: 470, y: 200, width: 80, height: 40, price: 120, zone: 'D' },
  { id: '20', number: 'D-5', status: 'free', x: 470, y: 250, width: 80, height: 40, price: 120, zone: 'D' },
];

export function DriverApp({ onBack, userProfile, onProfileUpdate }: DriverAppProps) {
  const [parkingSpots, setParkingSpots] = useState<ParkingSpot[]>(mockParkingSpots);
  const [selectedSpot, setSelectedSpot] = useState<ParkingSpot | null>(null);
  const [bookingDialogOpen, setBookingDialogOpen] = useState(false);
  
  const [profile, setProfile] = useState<UserProfile>(
    userProfile || {
      name: '',
      email: '',
      phone: '',
      carNumber: '',
      carBrand: '',
      carModel: '',
    }
  );

  const handleProfileUpdate = (updatedProfile: UserProfile) => {
    setProfile(updatedProfile);
    onProfileUpdate?.(updatedProfile);
  };

  const handleSpotClick = (spot: ParkingSpot) => {
    if (spot.status === 'free') {
      setSelectedSpot(spot);
      setBookingDialogOpen(true);
    }
  };

  const handleBooking = (spotId: string) => {
    setParkingSpots(spots =>
      spots.map(spot =>
        spot.id === spotId ? { ...spot, status: 'reserved' as const } : spot
      )
    );
    setBookingDialogOpen(false);
    setSelectedSpot(null);
  };

  const freeSpots = parkingSpots.filter(spot => spot.status === 'free').length;
  const totalSpots = parkingSpots.length;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b sticky top-0 z-10">
        <div className="px-4 py-3">
          <div className="flex items-center gap-3 mb-3">
            <Button variant="ghost" size="icon" onClick={onBack}>
              <ArrowLeft className="w-5 h-5" />
            </Button>
            <div className="flex-1">
              <h2 className="text-blue-900">Лайт Парк</h2>
              <p className="text-gray-600">ТЦ Мега, Уровень 1</p>
            </div>
          </div>
          
          <div className="flex gap-2">
            <div className="flex-1 bg-green-50 border border-green-200 rounded-lg p-3">
              <div className="text-green-600">Свободно</div>
              <div className="text-green-900">{freeSpots} мест</div>
            </div>
            <div className="flex-1 bg-gray-50 border border-gray-200 rounded-lg p-3">
              <div className="text-gray-600">Всего</div>
              <div className="text-gray-900">{totalSpots} мест</div>
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <Tabs defaultValue="profile" className="w-full">
        <TabsList className="w-full rounded-none border-b bg-white grid grid-cols-4">
          <TabsTrigger value="citymap" className="flex-1">
            <MapPin className="w-4 h-4 mr-2" />
            Город
          </TabsTrigger>
          <TabsTrigger value="map" className="flex-1">
            <Map className="w-4 h-4 mr-2" />
            Парковка
          </TabsTrigger>
          <TabsTrigger value="list" className="flex-1">
            <List className="w-4 h-4 mr-2" />
            Список
          </TabsTrigger>
          <TabsTrigger value="profile" className="flex-1">
            <User className="w-4 h-4 mr-2" />
            Профиль
          </TabsTrigger>
        </TabsList>

        <TabsContent value="citymap" className="m-0">
          <div className="bg-white h-[calc(100vh-250px)] flex items-center justify-center">
            <p className="text-gray-500">Тут будет ваш город</p>
          </div>
        </TabsContent>

        <TabsContent value="map" className="m-0">
          <ParkingMap
            spots={parkingSpots}
            onSpotClick={handleSpotClick}
            selectedSpot={selectedSpot}
          />
        </TabsContent>

        <TabsContent value="list" className="m-0">
          <ParkingList
            spots={parkingSpots}
            onSpotClick={handleSpotClick}
          />
        </TabsContent>

        <TabsContent value="profile" className="m-0">
          <DriverProfile
            profile={profile}
            onProfileUpdate={handleProfileUpdate}
          />
        </TabsContent>
      </Tabs>

      {/* Booking Dialog */}
      {selectedSpot && (
        <BookingDialog
          open={bookingDialogOpen}
          onOpenChange={setBookingDialogOpen}
          spot={selectedSpot}
          onBook={handleBooking}
        />
      )}
    </div>
  );
}