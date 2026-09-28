import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Switch } from './ui/switch';
import { Badge } from './ui/badge';
import { Save, Plus } from 'lucide-react';
import { toast } from 'sonner@2.0.3';

interface Tariff {
  id: string;
  zone: string;
  name: string;
  price: number;
  enabled: boolean;
}

const initialTariffs: Tariff[] = [
  { id: '1', zone: 'A', name: 'Зона A - Стандарт', price: 100, enabled: true },
  { id: '2', zone: 'B', name: 'Зона B - Эконом', price: 80, enabled: true },
  { id: '3', zone: 'C', name: 'Зона C - Премиум', price: 120, enabled: true },
  { id: '4', zone: 'D', name: 'Зона D - Премиум', price: 120, enabled: true },
];

export function TariffSettings() {
  const [tariffs, setTariffs] = useState<Tariff[]>(initialTariffs);
  const [editingId, setEditingId] = useState<string | null>(null);

  const handlePriceChange = (id: string, newPrice: string) => {
    const price = parseInt(newPrice) || 0;
    setTariffs(tariffs.map(t => (t.id === id ? { ...t, price } : t)));
  };

  const handleToggle = (id: string) => {
    setTariffs(tariffs.map(t => (t.id === id ? { ...t, enabled: !t.enabled } : t)));
  };

  const handleSave = () => {
    toast.success('Тарифы успешно сохранены!');
    setEditingId(null);
  };

  return (
    <div className="p-4 space-y-4">
      <Card>
        <CardHeader>
          <CardTitle>Управление тарифами</CardTitle>
          <CardDescription>Настройка цен для разных зон парковки</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {tariffs.map(tariff => (
            <Card key={tariff.id}>
              <CardContent className="pt-6">
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="text-gray-900 flex items-center gap-2">
                        {tariff.name}
                        <Badge variant="outline">Зона {tariff.zone}</Badge>
                      </div>
                    </div>
                    <Switch
                      checked={tariff.enabled}
                      onCheckedChange={() => handleToggle(tariff.id)}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor={`price-${tariff.id}`}>Цена за час (₽)</Label>
                    <div className="flex gap-2">
                      <Input
                        id={`price-${tariff.id}`}
                        type="number"
                        value={tariff.price}
                        onChange={e => handlePriceChange(tariff.id, e.target.value)}
                        disabled={!tariff.enabled}
                        className="flex-1"
                      />
                      <Button
                        variant="outline"
                        onClick={() => setEditingId(tariff.id)}
                        disabled={!tariff.enabled}
                      >
                        Изменить
                      </Button>
                    </div>
                  </div>

                  {!tariff.enabled && (
                    <div className="text-amber-600 bg-amber-50 p-3 rounded-lg">
                      Тариф отключен и недоступен для бронирования
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}

          <Button className="w-full" onClick={handleSave}>
            <Save className="w-4 h-4 mr-2" />
            Сохранить изменения
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Специальные предложения</CardTitle>
          <CardDescription>Скидки и акции для клиентов</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Card className="border-dashed">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-gray-900">Ночной тариф</div>
                  <div className="text-gray-500">22:00 - 06:00, скидка 30%</div>
                </div>
                <Switch defaultChecked />
              </div>
            </CardContent>
          </Card>

          <Card className="border-dashed">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-gray-900">Выходные</div>
                  <div className="text-gray-500">Суббота-воскресенье, +20%</div>
                </div>
                <Switch defaultChecked />
              </div>
            </CardContent>
          </Card>

          <Card className="border-dashed">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-gray-900">Долгосрочная аренда</div>
                  <div className="text-gray-500">Более 5 часов, скидка 15%</div>
                </div>
                <Switch />
              </div>
            </CardContent>
          </Card>

          <Button variant="outline" className="w-full">
            <Plus className="w-4 h-4 mr-2" />
            Добавить предложение
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Настройки оплаты</CardTitle>
          <CardDescription>Способы оплаты и интеграции</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                💳
              </div>
              <div>
                <div className="text-gray-900">Банковские карты</div>
                <div className="text-gray-500">Visa, MasterCard, Мир</div>
              </div>
            </div>
            <Badge>Активно</Badge>
          </div>

          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                📱
              </div>
              <div>
                <div className="text-gray-900">СБП</div>
                <div className="text-gray-500">Система быстрых платежей</div>
              </div>
            </div>
            <Badge>Активно</Badge>
          </div>

          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gray-200 rounded-lg flex items-center justify-center">
                🏦
              </div>
              <div>
                <div className="text-gray-900">Корпоративные счета</div>
                <div className="text-gray-500">Для юридических лиц</div>
              </div>
            </div>
            <Badge variant="outline">Не настроено</Badge>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
