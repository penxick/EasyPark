import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line, PieChart, Pie, Cell } from 'recharts';
import { TrendingUp, DollarSign, Users, Clock } from 'lucide-react';

const dailyRevenueData = [
  { day: 'Пн', revenue: 8500 },
  { day: 'Вт', revenue: 9200 },
  { day: 'Ср', revenue: 11000 },
  { day: 'Чт', revenue: 10500 },
  { day: 'Пт', revenue: 13000 },
  { day: 'Сб', revenue: 15500 },
  { day: 'Вс', revenue: 14200 },
];

const hourlyData = [
  { hour: '06:00', bookings: 2 },
  { hour: '08:00', bookings: 8 },
  { hour: '10:00', bookings: 15 },
  { hour: '12:00', bookings: 18 },
  { hour: '14:00', bookings: 20 },
  { hour: '16:00', bookings: 17 },
  { hour: '18:00', bookings: 12 },
  { hour: '20:00', bookings: 6 },
];

const zoneData = [
  { zone: 'Зона A', value: 35, color: '#3b82f6' },
  { zone: 'Зона B', value: 25, color: '#10b981' },
  { zone: 'Зона C', value: 25, color: '#f59e0b' },
  { zone: 'Зона D', value: 15, color: '#8b5cf6' },
];

export function RevenueAnalytics() {
  return (
    <div className="p-4 space-y-4">
      {/* Основные метрики */}
      <div className="grid grid-cols-2 gap-3">
        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-2">
              <DollarSign className="w-4 h-4" />
              Неделя
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-blue-900">81 900 ₽</div>
            <p className="text-green-600 flex items-center gap-1 mt-1">
              <TrendingUp className="w-3 h-3" />
              +12%
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-2">
              <DollarSign className="w-4 h-4" />
              Месяц
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-blue-900">328 500 ₽</div>
            <p className="text-green-600 flex items-center gap-1 mt-1">
              <TrendingUp className="w-3 h-3" />
              +18%
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-2">
              <Users className="w-4 h-4" />
              Клиентов
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-blue-900">1 247</div>
            <p className="text-gray-500 mt-1">За неделю</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-2">
              <Clock className="w-4 h-4" />
              Ср. время
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-blue-900">2.5 часа</div>
            <p className="text-gray-500 mt-1">На место</p>
          </CardContent>
        </Card>
      </div>

      {/* График выручки */}
      <Card>
        <CardHeader>
          <CardTitle>Выручка по дням недели</CardTitle>
          <CardDescription>Общая выручка за последнюю неделю</CardDescription>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={dailyRevenueData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="day" stroke="#6b7280" />
              <YAxis stroke="#6b7280" />
              <Tooltip
                contentStyle={{
                  backgroundColor: 'white',
                  border: '1px solid #e5e7eb',
                  borderRadius: '8px',
                }}
              />
              <Bar dataKey="revenue" fill="#3b82f6" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      {/* График бронирований по часам */}
      <Card>
        <CardHeader>
          <CardTitle>Загруженность по времени</CardTitle>
          <CardDescription>Количество бронирований по часам</CardDescription>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={hourlyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="hour" stroke="#6b7280" />
              <YAxis stroke="#6b7280" />
              <Tooltip
                contentStyle={{
                  backgroundColor: 'white',
                  border: '1px solid #e5e7eb',
                  borderRadius: '8px',
                }}
              />
              <Line
                type="monotone"
                dataKey="bookings"
                stroke="#10b981"
                strokeWidth={2}
                dot={{ fill: '#10b981', r: 4 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      {/* Распределение по зонам */}
      <Card>
        <CardHeader>
          <CardTitle>Популярность зон</CardTitle>
          <CardDescription>Распределение бронирований по зонам</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-center">
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={zoneData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ zone, value }) => `${zone}: ${value}%`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {zoneData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="grid grid-cols-2 gap-2 mt-4">
            {zoneData.map(zone => (
              <div key={zone.zone} className="flex items-center gap-2">
                <div
                  className="w-4 h-4 rounded"
                  style={{ backgroundColor: zone.color }}
                />
                <span className="text-gray-600">{zone.zone}</span>
                <span className="text-gray-900 ml-auto">{zone.value}%</span>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Топ клиенты */}
      <Card>
        <CardHeader>
          <CardTitle>Топ клиентов</CardTitle>
          <CardDescription>Самые частые посетители</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          {[
            { car: 'К123АВ', visits: 24, spent: 4800 },
            { car: 'М456СД', visits: 18, spent: 3600 },
            { car: 'О789ЕФ', visits: 15, spent: 3000 },
            { car: 'Т111ГХ', visits: 12, spent: 2400 },
          ].map((client, idx) => (
            <div
              key={idx}
              className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
            >
              <div>
                <div className="text-gray-900">{client.car}</div>
                <div className="text-gray-500">{client.visits} визитов</div>
              </div>
              <div className="text-blue-600">{client.spent} ₽</div>
            </div>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
