import { useState } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { UserPlus, Mail, Lock, ArrowLeft } from 'lucide-react';
import { toast } from 'sonner@2.0.3';

interface RegisterScreenProps {
  onRegister: () => void;
  onBack: () => void;
}

export function RegisterScreen({ onRegister, onBack }: RegisterScreenProps) {
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (password !== confirmPassword) {
      toast.error('Пароли не совпадают', {
        description: 'Проверьте правильность ввода паролей',
      });
      return;
    }

    if (password.length < 5) {
      toast.error('Слишком короткий пароль', {
        description: 'Пароль должен содержать минимум 5 символов',
      });
      return;
    }

    setIsLoading(true);

    // Имитация регистрации
    setTimeout(() => {
      toast.success('Регистрация успешна!', {
        description: 'Теперь вы можете войти в систему',
      });
      setIsLoading(false);
      onRegister();
    }, 800);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="space-y-4">
          <div className="text-center">
            <CardTitle className="text-blue-900">Регистрация</CardTitle>
            <CardDescription>
              Создайте новый аккаунт для использования Лайт Парк
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="register-login" className="flex items-center gap-2">
                <Mail className="w-4 h-4" />
                Логин
              </Label>
              <Input
                id="register-login"
                type="text"
                placeholder="Номер телефона или почта"
                value={login}
                onChange={(e) => setLogin(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="register-password" className="flex items-center gap-2">
                <Lock className="w-4 h-4" />
                Пароль
              </Label>
              <Input
                id="register-password"
                type="password"
                placeholder="Введите пароль"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={isLoading}
                minLength={5}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="register-confirm-password" className="flex items-center gap-2">
                <Lock className="w-4 h-4" />
                Подтверждение пароля
              </Label>
              <Input
                id="register-confirm-password"
                type="password"
                placeholder="Повторите пароль"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                disabled={isLoading}
                minLength={5}
              />
            </div>
            <Button
              type="submit"
              className="w-full bg-blue-600 hover:bg-blue-700"
              disabled={isLoading}
            >
              <UserPlus className="w-4 h-4 mr-2" />
              {isLoading ? 'Регистрация...' : 'Зарегистрироваться'}
            </Button>
          </form>

          <div className="mt-4">
            <Button
              variant="ghost"
              onClick={onBack}
              className="w-full text-gray-600 hover:text-gray-900"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              Вернуться ко входу
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}