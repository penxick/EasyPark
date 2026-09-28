import { ParkingSpot } from './DriverApp';
import { Badge } from './ui/badge';

interface ParkingMapProps {
  spots: ParkingSpot[];
  onSpotClick: (spot: ParkingSpot) => void;
  selectedSpot: ParkingSpot | null;
}

export function ParkingMap({ spots, onSpotClick, selectedSpot }: ParkingMapProps) {
  return (
    <div className="p-4">
      <div className="bg-white rounded-lg shadow-lg p-4 mb-4">
        <div className="flex gap-4 flex-wrap">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 bg-green-500 rounded"></div>
            <span className="text-gray-700">Свободно</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 bg-red-500 rounded"></div>
            <span className="text-gray-700">Занято</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 bg-yellow-500 rounded"></div>
            <span className="text-gray-700">Забронировано</span>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-lg overflow-hidden">
        <div className="relative" style={{ paddingBottom: '75%' }}>
          <svg
            className="absolute inset-0 w-full h-full"
            viewBox="0 0 600 350"
            xmlns="http://www.w3.org/2000/svg"
          >
            {/* Дороги */}
            <rect x="0" y="0" width="600" height="350" fill="#f3f4f6" />
            <rect x="250" y="0" width="100" height="350" fill="#d1d5db" />
            
            {/* Разметка дороги */}
            <line x1="300" y1="0" x2="300" y2="350" stroke="#9ca3af" strokeWidth="2" strokeDasharray="10,10" />
            
            {/* Зоны */}
            <text x="90" y="30" fill="#6b7280" fontSize="14">Зона A</text>
            <text x="190" y="30" fill="#6b7280" fontSize="14">Зона B</text>
            <text x="410" y="30" fill="#6b7280" fontSize="14">Зона C</text>
            <text x="510" y="30" fill="#6b7280" fontSize="14">Зона D</text>
            
            {/* Парковочные места */}
            {spots.map((spot) => {
              const isSelected = selectedSpot?.id === spot.id;
              const fillColor =
                spot.status === 'free'
                  ? '#10b981'
                  : spot.status === 'occupied'
                  ? '#ef4444'
                  : '#eab308';
              
              return (
                <g
                  key={spot.id}
                  onClick={() => onSpotClick(spot)}
                  className={spot.status === 'free' ? 'cursor-pointer hover:opacity-80' : 'cursor-not-allowed'}
                  style={{ transition: 'opacity 0.2s' }}
                >
                  <rect
                    x={spot.x}
                    y={spot.y}
                    width={spot.width}
                    height={spot.height}
                    fill={fillColor}
                    stroke={isSelected ? '#3b82f6' : '#ffffff'}
                    strokeWidth={isSelected ? '3' : '2'}
                    rx="4"
                  />
                  <text
                    x={spot.x + spot.width / 2}
                    y={spot.y + spot.height / 2 + 5}
                    fill="white"
                    fontSize="12"
                    textAnchor="middle"
                  >
                    {spot.number}
                  </text>
                </g>
              );
            })}
            
            {/* Вход/выход */}
            <rect x="260" y="320" width="80" height="25" fill="#3b82f6" rx="4" />
            <text x="300" y="337" fill="white" fontSize="12" textAnchor="middle">ВХОД</text>
          </svg>
        </div>
      </div>

      {/* Информация о зонах */}
      <div className="mt-4 grid grid-cols-2 gap-3">
        {['A', 'B', 'C', 'D'].map(zone => {
          const zoneSpots = spots.filter(s => s.zone === zone);
          const freeInZone = zoneSpots.filter(s => s.status === 'free').length;
          const price = zoneSpots[0]?.price || 0;
          
          return (
            <div key={zone} className="bg-white rounded-lg p-3 border">
              <div className="flex items-center justify-between mb-1">
                <span className="text-gray-900">Зона {zone}</span>
                <Badge variant={freeInZone > 0 ? 'default' : 'secondary'}>
                  {freeInZone}/{zoneSpots.length}
                </Badge>
              </div>
              <div className="text-blue-600">{price} ₽/час</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
