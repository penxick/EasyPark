import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Badge } from './ui/badge';
import { Button } from './ui/button';
import { RefreshCw } from 'lucide-react';

interface SpotStatus {
  id: string;
  number: string;
  status: 'free' | 'occupied' | 'reserved';
  zone: string;
  car?: string;
  startTime?: string;
  duration?: string;
}

const mockSpots: SpotStatus[] = [
  { id: '1', number: 'A-1', status: 'reserved', zone: 'A', car: 'К123АВ', startTime: '14:30', duration: '2ч' },
  { id: '2', number: 'A-2', status: 'occupied', zone: 'A', car: 'М456СД', startTime: '13:00' },
  { id: '3', number: 'A-3', status: 'free', zone: 'A' },
  { id: '4', number: 'A-4', status: 'free', zone: 'A' },
  { id: '5', number: 'A-5', status: 'occupied', zone: 'A', car: 'О789ЕФ', startTime: '12:15' },
  { id: '6', number: 'B-1', status: 'free', zone: 'B' },
  { id: '7', number: 'B-2', status: 'free', zone: 'B' },
  { id: '8', number: 'B-3', status: 'occupied', zone: 'B', car: 'Т111ГХ', startTime: '14:00' },
  { id: '9', number: 'B-4', status: 'free', zone: 'B' },
  { id: '10', number: 'B-5', status: 'free', zone: 'B' },
  { id: '11', number: 'C-1', status: 'occupied', zone: 'C', car: 'Н222ИЙ', startTime: '11:30' },
  { id: '12', number: 'C-2', status: 'reserved', zone: 'C', car: 'Р333КЛ', startTime: '15:00', duration: '1ч' },
  { id: '13', number: 'C-3', status: 'free', zone: 'C' },
  { id: '14', number: 'C-4', status: 'occupied', zone: 'C', car: 'С444МН', startTime: '13:45' },
  { id: '15', number: 'C-5', status: 'free', zone: 'C' },
  { id: '16', number: 'D-1', status: 'free', zone: 'D' },
  { id: '17', number: 'D-2', status: 'free', zone: 'D' },
  { id: '18', number: 'D-3', status: 'occupied', zone: 'D', car: 'У555ОП', startTime: '14:20' },
  { id: '19', number: 'D-4', status: 'free', zone: 'D' },
  { id: '20', number: 'D-5', status: 'reserved', zone: 'D', car: 'Ф666РС', startTime: '15:15', duration: '3ч' },
];

export function ParkingMonitor() {
  const [spots] = useState<SpotStatus[]>(mockSpots);
  const [selectedZone, setSelectedZone] = useState<string>('all');

  const filteredSpots = selectedZone === 'all'
    ? spots
    : spots.filter(spot => spot.zone === selectedZone);

  const zones = ['all', 'A', 'B', 'C', 'D'];

  return (
    <div className="p-4 space-y-4">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Мониторинг парковки</CardTitle>
            <Button variant="outline" size="icon">
              <RefreshCw className="w-4 h-4" />
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex gap-2 overflow-x-auto pb-2">
            {zones.map(zone => (
              <Button
                key={zone}
                variant={selectedZone === zone ? 'default' : 'outline'}
                onClick={() => setSelectedZone(zone)}
                size="sm"
              >
                {zone === 'all' ? 'Все зоны' : `Зона ${zone}`}
              </Button>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-3">
        {filteredSpots.map(spot => (
          <Card key={spot.id} className="overflow-hidden">
            <div className="flex">
              <div
                className={`w-2 ${
                  spot.status === 'free'
                    ? 'bg-green-500'
                    : spot.status === 'occupied'
                    ? 'bg-red-500'
                    : 'bg-yellow-500'
                }`}
              />
              <div className="flex-1 p-4">
                <div className="flex items-start justify-between mb-2">
                  <div className="flex items-center gap-3">
                    <div
                      className={`w-12 h-12 rounded-lg flex items-center justify-center text-white ${
                        spot.status === 'free'
                          ? 'bg-green-500'
                          : spot.status === 'occupied'
                          ? 'bg-red-500'
                          : 'bg-yellow-500'
                      }`}
                    >
                      {spot.number}
                    </div>
                    <div>
                      <div className="text-gray-900">Место {spot.number}</div>
                      <div className="text-gray-500">Зона {spot.zone}</div>
                    </div>
                  </div>
                  <Badge
                    variant={
                      spot.status === 'free'
                        ? 'default'
                        : spot.status === 'occupied'
                        ? 'destructive'
                        : 'secondary'
                    }
                  >
                    {spot.status === 'free'
                      ? 'Свободно'
                      : spot.status === 'occupied'
                      ? 'Занято'
                      : 'Бронь'}
                  </Badge>
                </div>

                {spot.car && (
                  <div className="mt-3 pt-3 border-t space-y-1">
                    <div className="flex items-center justify-between text-gray-600">
                      <span>Автомобиль:</span>
                      <span className="text-gray-900">{spot.car}</span>
                    </div>
                    {spot.startTime && (
                      <div className="flex items-center justify-between text-gray-600">
                        <span>Время въезда:</span>
                        <span className="text-gray-900">{spot.startTime}</span>
                      </div>
                    )}
                    {spot.duration && (
                      <div className="flex items-center justify-between text-gray-600">
                        <span>Длительность:</span>
                        <span className="text-gray-900">{spot.duration}</span>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
