import { useState, useEffect } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { User, Mail, Phone, Car, Save } from 'lucide-react';
import { toast } from 'sonner@2.0.3';

export interface UserProfile {
  name: string;
  email: string;
  phone: string;
  carNumber: string;
  carBrand: string;
  carModel: string;
}

interface DriverProfileProps {
  profile: UserProfile;
  onProfileUpdate: (profile: UserProfile) => void;
}

export function DriverProfile({ profile, onProfileUpdate }: DriverProfileProps) {
  const [formData, setFormData] = useState<UserProfile>(profile);
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    setFormData(profile);
  }, [profile]);

  const handleChange = (field: keyof UserProfile, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    setIsEditing(true);
  };

  const handleSave = () => {
    if (!formData.carNumber.trim()) {
      toast.error('Введите номер машины', {
        description: 'Номер машины обязателен для бронирования мест',
      });
      return;
    }

    setIsSaving(true);
    
    // Имитация сохранения
    setTimeout(() => {
      onProfileUpdate(formData);
      setIsEditing(false);
      setIsSaving(false);
      toast.success('Профиль обновлен', {
        description: 'Ваши данные успешно сохранены',
      });
    }, 500);
  };

  const isProfileComplete = formData.name && formData.carNumber;

  return (
    <div className="p-4 space-y-4 max-w-2xl mx-auto">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <User className="w-5 h-5" />
            Профиль водителя
          </CardTitle>
          <CardDescription>
            Управление личными данными и информацией об автомобиле
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Personal Information */}
          <div className="space-y-4">
            <h3 className="text-gray-900">Личные данные</h3>
            
            <div className="space-y-2">
              <Label htmlFor="name" className="flex items-center gap-2">
                <User className="w-4 h-4" />
                Имя
              </Label>
              <Input
                id="name"
                type="text"
                placeholder="Введите ваше имя"
                value={formData.name}
                onChange={(e) => handleChange('name', e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="email" className="flex items-center gap-2">
                <Mail className="w-4 h-4" />
                Email
              </Label>
              <Input
                id="email"
                type="email"
                placeholder="example@email.com"
                value={formData.email}
                onChange={(e) => handleChange('email', e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="phone" className="flex items-center gap-2">
                <Phone className="w-4 h-4" />
                Телефон
              </Label>
              <Input
                id="phone"
                type="tel"
                placeholder="+7 (___) ___-__-__"
                value={formData.phone}
                onChange={(e) => handleChange('phone', e.target.value)}
              />
            </div>
          </div>

          {/* Car Information */}
          <div className="space-y-4 pt-4 border-t">
            <h3 className="text-gray-900 flex items-center gap-2">
              <Car className="w-5 h-5" />
              Информация об автомобиле
            </h3>
            
            <div className="space-y-2">
              <Label htmlFor="carNumber" className="flex items-center gap-2">
                Номер автомобиля <span className="text-red-500">*</span>
              </Label>
              <Input
                id="carNumber"
                type="text"
                placeholder="А123БВ777"
                value={formData.carNumber}
                onChange={(e) => handleChange('carNumber', e.target.value.toUpperCase())}
                className={!formData.carNumber.trim() ? 'border-red-300' : ''}
              />
              {!formData.carNumber.trim() && (
                <p className="text-red-500">Обязательное поле</p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="carBrand">Марка</Label>
                <Input
                  id="carBrand"
                  type="text"
                  placeholder="Toyota"
                  value={formData.carBrand}
                  onChange={(e) => handleChange('carBrand', e.target.value)}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="carModel">Модель</Label>
                <Input
                  id="carModel"
                  type="text"
                  placeholder="Camry"
                  value={formData.carModel}
                  onChange={(e) => handleChange('carModel', e.target.value)}
                />
              </div>
            </div>
          </div>

          {/* Save Button */}
          <div className="pt-4">
            <Button
              onClick={handleSave}
              disabled={!isEditing || isSaving || !isProfileComplete}
              className="w-full bg-blue-600 hover:bg-blue-700"
            >
              <Save className="w-4 h-4 mr-2" />
              {isSaving ? 'Сохранение...' : 'Сохранить изменения'}
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Profile Status Card */}
      {!isProfileComplete && (
        <Card className="border-yellow-300 bg-yellow-50">
          <CardContent className="pt-6">
            <div className="flex items-start gap-3">
              <div className="text-yellow-600">⚠️</div>
              <div>
                <p className="text-yellow-900">Заполните профиль</p>
                <p className="text-yellow-700">
                  Для бронирования парковочных мест необходимо указать номер вашего автомобиля
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {isProfileComplete && (
        <Card className="border-green-300 bg-green-50">
          <CardContent className="pt-6">
            <div className="flex items-start gap-3">
              <div className="text-green-600">✓</div>
              <div>
                <p className="text-green-900">Профиль заполнен</p>
                <p className="text-green-700">
                  Вы можете бронировать парковочные места
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
