import { useState } from 'react';
import { ParkingSpot } from './DriverApp';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from './ui/dialog';
import { Button } from './ui/button';
import { RadioGroup, RadioGroupItem } from './ui/radio-group';
import { Label } from './ui/label';
import { CreditCard, Smartphone, Clock } from 'lucide-react';
import { toast } from 'sonner@2.0.3';

interface BookingDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  spot: ParkingSpot;
  onBook: (spotId: string) => void;
}

export function BookingDialog({ open, onOpenChange, spot, onBook }: BookingDialogProps) {
  const [duration, setDuration] = useState('1');
  const [paymentMethod, setPaymentMethod] = useState('card');
  const [isProcessing, setIsProcessing] = useState(false);

  const totalPrice = spot.price * parseInt(duration);

  const handleConfirmBooking = () => {
    setIsProcessing(true);
    
    // Имитация обработки платежа
    setTimeout(() => {
      onBook(spot.id);
      setIsProcessing(false);
      toast.success('Место успешно забронировано!', {
        description: `Место ${spot.number} забронировано на ${duration} час(а)`,
      });
    }, 1500);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Бронирование места</DialogTitle>
          <DialogDescription>
            Выберите длительность парковки и способ оплаты
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6 py-4">
          {/* Информация о месте */}
          <div className="bg-blue-50 rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-gray-600">Место</span>
              <span className="text-blue-900">{spot.number}</span>
            </div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-gray-600">Зона</span>
              <span className="text-blue-900">Зона {spot.zone}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">Тариф</span>
              <span className="text-blue-900">{spot.price} ₽/час</span>
            </div>
          </div>

          {/* Выбор длительности */}
          <div>
            <Label className="flex items-center gap-2 mb-3">
              <Clock className="w-4 h-4" />
              Длительность
            </Label>
            <RadioGroup value={duration} onValueChange={setDuration}>
              <div className="grid grid-cols-3 gap-2">
                {['1', '2', '3', '4', '5', '6'].map(hours => (
                  <div key={hours}>
                    <RadioGroupItem
                      value={hours}
                      id={`duration-${hours}`}
                      className="peer sr-only"
                    />
                    <Label
                      htmlFor={`duration-${hours}`}
                      className="flex items-center justify-center rounded-lg border-2 border-gray-200 bg-white p-3 hover:bg-gray-50 peer-data-[state=checked]:border-blue-600 peer-data-[state=checked]:bg-blue-50 cursor-pointer transition-colors"
                    >
                      {hours}ч
                    </Label>
                  </div>
                ))}
              </div>
            </RadioGroup>
          </div>

          {/* Способ оплаты */}
          <div>
            <Label className="mb-3 block">Способ оплаты</Label>
            <RadioGroup value={paymentMethod} onValueChange={setPaymentMethod}>
              <div className="space-y-2">
                <div className="flex items-center space-x-2 border rounded-lg p-3 hover:border-blue-500 transition-colors">
                  <RadioGroupItem value="card" id="card" />
                  <Label htmlFor="card" className="flex items-center gap-2 flex-1 cursor-pointer">
                    <CreditCard className="w-4 h-4 text-blue-600" />
                    Банковская карта
                  </Label>
                </div>
                <div className="flex items-center space-x-2 border rounded-lg p-3 hover:border-blue-500 transition-colors">
                  <RadioGroupItem value="sbp" id="sbp" />
                  <Label htmlFor="sbp" className="flex items-center gap-2 flex-1 cursor-pointer">
                    <Smartphone className="w-4 h-4 text-blue-600" />
                    СБП (Система быстрых платежей)
                  </Label>
                </div>
              </div>
            </RadioGroup>
          </div>

          {/* Итого */}
          <div className="bg-gray-50 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <span className="text-gray-900">Итого к оплате:</span>
              <span className="text-blue-600">{totalPrice} ₽</span>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={isProcessing}
          >
            Отмена
          </Button>
          <Button
            onClick={handleConfirmBooking}
            disabled={isProcessing}
            className="bg-blue-600 hover:bg-blue-700"
          >
            {isProcessing ? 'Обработка...' : 'Оплатить и забронировать'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
