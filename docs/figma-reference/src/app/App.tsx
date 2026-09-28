import { useState } from 'react';
import { DriverApp } from './components/DriverApp';
import { OperatorApp } from './components/OperatorApp';
import { LoginScreen } from './components/LoginScreen';
import { RegisterScreen } from './components/RegisterScreen';
import { UserProfile } from './components/DriverProfile';
import { Button } from './components/ui/button';
import { Car, LayoutDashboard, LogOut } from 'lucide-react';
import logo from 'figma:asset/8c061ed90e1159eb53e3706b49f6d13552854bd4.png';

type AppMode = 'login' | 'register' | 'selection' | 'driver' | 'operator';
type UserType = 'admin' | 'driver' | null;

export default function App() {
  const [mode, setMode] = useState<AppMode>('login');
  const [userType, setUserType] = useState<UserType>(null);
  const [userProfile, setUserProfile] = useState<UserProfile>({
    name: '',
    email: '',
    phone: '',
    carNumber: '',
    carBrand: '',
    carModel: '',
  });

  const handleLogin = (type: 'admin' | 'driver') => {
    setUserType(type);
    if (type === 'driver') {
      // Водитель сразу переходит в приложение
      setMode('driver');
    } else {
      // Администратор видит выбор
      setMode('selection');
    }
  };

  const handleLogout = () => {
    setUserType(null);
    setMode('login');
  };

  const handleBack = () => {
    if (userType === 'admin') {
      setMode('selection');
    } else {
      handleLogout();
    }
  };

  if (mode === 'login') {
    return <LoginScreen onLogin={handleLogin} onRegister={() => setMode('register')} />;
  }

  if (mode === 'register') {
    return <RegisterScreen onRegister={() => setMode('login')} onBack={() => setMode('login')} />;
  }

  if (mode === 'driver') {
    return <DriverApp onBack={handleBack} userProfile={userProfile} onProfileUpdate={setUserProfile} />;
  }

  if (mode === 'operator') {
    return <OperatorApp onBack={handleBack} />;
  }

  // Экран выбора для администратора
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="max-w-md w-full">
        <div className="text-center mb-8">
          <div className="inline-block bg-white rounded-3xl p-6 mb-4 shadow-lg">
            <img src={logo} alt="Лайт Парк Logo" className="w-32 h-32" />
          </div>
          <h2 className="text-blue-900 mb-2">Панель администратора</h2>
          <p className="text-gray-600">Выберите режим работы</p>
        </div>

        <div className="space-y-4">
          <Button
            onClick={() => setMode('driver')}
            className="w-full h-24 bg-white hover:bg-gray-50 text-gray-900 border-2 border-gray-200 hover:border-blue-500 transition-all"
            variant="outline"
          >
            <div className="flex flex-col items-center gap-2">
              <Car className="w-8 h-8 text-blue-600" />
              <div>
                <div>Найти место</div>
                <div className="text-gray-500">Поиск парковочного места</div>
              </div>
            </div>
          </Button>

          <Button
            onClick={() => setMode('operator')}
            className="w-full h-24 bg-white hover:bg-gray-50 text-gray-900 border-2 border-gray-200 hover:border-blue-500 transition-all"
            variant="outline"
          >
            <div className="flex flex-col items-center gap-2">
              <LayoutDashboard className="w-8 h-8 text-blue-600" />
              <div>
                <div>Управление</div>
                <div className="text-gray-500">Панель управления парковкой</div>
              </div>
            </div>
          </Button>

          <Button
            onClick={handleLogout}
            className="w-full bg-white hover:bg-gray-50 text-gray-700 border-2 border-gray-200 hover:border-red-400 transition-all"
            variant="outline"
          >
            <LogOut className="w-4 h-4 mr-2" />
            Выйти
          </Button>
        </div>
      </div>
    </div>
  );
}