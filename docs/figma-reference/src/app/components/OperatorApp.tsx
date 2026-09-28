import { useState } from 'react';
import { Button } from './ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs';
import { Badge } from './ui/badge';
import {
  ArrowLeft,
  LayoutDashboard,
  DollarSign,
  MapPin,
  TrendingUp,
  Users,
  Clock,
  Settings,
} from 'lucide-react';
import { ParkingMonitor } from './ParkingMonitor';
import { RevenueAnalytics } from './RevenueAnalytics';
import { TariffSettings } from './TariffSettings';

interface OperatorAppProps {
  onBack: () => void;
}

export function OperatorApp({ onBack }: OperatorAppProps) {
  const [currentTab, setCurrentTab] = useState('dashboard');

  // Демо-данные
  const stats = {
    totalSpots: 20,
    occupiedSpots: 8,
    reservedSpots: 3,
    freeSpots: 9,
    todayRevenue: 12450,
    avgOccupancy: 67,
    activeBookings: 3,
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b">
        <div className="px-4 py-4">
          <div className="flex items-center gap-3">
            <Button variant="ghost" size="icon" onClick={onBack}>
              <ArrowLeft className="w-5 h-5" />
            </Button>
            <div className="flex-1">
              <h2 className="text-blue-900">Лайт Парк - Панель оператора</h2>
              <p className="text-gray-600">ТЦ Мега, Уровень 1</p>
            </div>
          </div>
        </div>
      </div>

      <Tabs value={currentTab} onValueChange={setCurrentTab} className="w-full">
        <div className="overflow-x-auto bg-white border-b">
          <TabsList className="w-full min-w-max rounded-none bg-white h-auto p-0 inline-flex">
            <TabsTrigger value="dashboard" className="flex-1 whitespace-nowrap data-[state=active]:bg-blue-50">
              <LayoutDashboard className="w-4 h-4 mr-2" />
              Обзор
            </TabsTrigger>
            <TabsTrigger value="monitor" className="flex-1 whitespace-nowrap data-[state=active]:bg-blue-50">
              <MapPin className="w-4 h-4 mr-2" />
              Мониторинг
            </TabsTrigger>
            <TabsTrigger value="analytics" className="flex-1 whitespace-nowrap data-[state=active]:bg-blue-50">
              <TrendingUp className="w-4 h-4 mr-2" />
              Аналитика
            </TabsTrigger>
            <TabsTrigger value="settings" className="flex-1 whitespace-nowrap data-[state=active]:bg-blue-50">
              <Settings className="w-4 h-4 mr-2" />
              Тарифы
            </TabsTrigger>
          </TabsList>
        </div>

        {/* Dashboard Tab */}
        <TabsContent value="dashboard" className="m-0 p-4 space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Всего мест</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-blue-900">{stats.totalSpots}</div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Занято</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-blue-900">{stats.occupiedSpots}</div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Забронировано</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-blue-900">{stats.reservedSpots}</div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Свободно</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-green-600">{stats.freeSpots}</div>
              </CardContent>
            </Card>
          </div>

          <Card className="bg-gradient-to-br from-blue-600 to-blue-700 text-white">
            <CardHeader>
              <div className="flex items-center gap-2">
                <DollarSign className="w-5 h-5" />
                <CardTitle className="text-white">Выручка за сегодня</CardTitle>
              </div>
            </CardHeader>
            <CardContent>
              <div className="text-white">{stats.todayRevenue.toLocaleString('ru-RU')} ₽</div>
              <p className="text-blue-100 mt-1">+15% к вчерашнему дню</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Загруженность парковки</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-gray-600">Средняя загруженность</span>
                  <Badge>{stats.avgOccupancy}%</Badge>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
                  <div
                    className="bg-blue-600 h-full rounded-full transition-all"
                    style={{ width: `${stats.avgOccupancy}%` }}
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Активные бронирования</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {[
                { spot: 'A-1', car: 'К123АВ', time: '14:30', duration: '2ч' },
                { spot: 'C-2', car: 'М456СД', time: '15:00', duration: '1ч' },
                { spot: 'D-5', car: 'О789ЕФ', time: '15:15', duration: '3ч' },
              ].map((booking, idx) => (
                <div key={idx} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-yellow-500 rounded flex items-center justify-center text-white">
                      {booking.spot}
                    </div>
                    <div>
                      <div className="text-gray-900">{booking.car}</div>
                      <div className="text-gray-500 flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {booking.time} • {booking.duration}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Monitor Tab */}
        <TabsContent value="monitor" className="m-0">
          <ParkingMonitor />
        </TabsContent>

        {/* Analytics Tab */}
        <TabsContent value="analytics" className="m-0">
          <RevenueAnalytics />
        </TabsContent>

        {/* Settings Tab */}
        <TabsContent value="settings" className="m-0">
          <TariffSettings />
        </TabsContent>
      </Tabs>
    </div>
  );
}