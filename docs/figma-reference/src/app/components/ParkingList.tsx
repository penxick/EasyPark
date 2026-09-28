import { ParkingSpot } from './DriverApp';
import { Button } from './ui/button';
import { Badge } from './ui/badge';
import { MapPin } from 'lucide-react';

interface ParkingListProps {
  spots: ParkingSpot[];
  onSpotClick: (spot: ParkingSpot) => void;
}

export function ParkingList({ spots, onSpotClick }: ParkingListProps) {
  const freeSpots = spots.filter(spot => spot.status === 'free');

  return (
    <div className="p-4 space-y-3">
      {freeSpots.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          <MapPin className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>Нет свободных мест</p>
        </div>
      ) : (
        freeSpots.map(spot => (
          <div
            key={spot.id}
            className="bg-white rounded-lg p-4 border border-gray-200 hover:border-blue-500 transition-colors"
          >
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-green-500 rounded-lg flex items-center justify-center text-white">
                  {spot.number}
                </div>
                <div>
                  <div className="text-gray-900">Место {spot.number}</div>
                  <div className="text-gray-500">Зона {spot.zone}</div>
                </div>
              </div>
              <Badge variant="outline" className="bg-green-50 text-green-700 border-green-200">
                Свободно
              </Badge>
            </div>
            
            <div className="flex items-center justify-between">
              <div className="text-blue-600">{spot.price} ₽/час</div>
              <Button onClick={() => onSpotClick(spot)}>
                Забронировать
              </Button>
            </div>
          </div>
        ))
      )}
    </div>
  );
}
