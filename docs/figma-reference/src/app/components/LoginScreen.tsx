import { useState } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { LogIn, Mail, Lock, UserPlus } from 'lucide-react';
import { toast } from 'sonner@2.0.3';

interface LoginScreenProps {
  onLogin: (userType: 'admin' | 'driver') => void;
  onRegister: () => void;
}

export function LoginScreen({ onLogin, onRegister }: LoginScreenProps) {
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    // Имитация проверки входа
    setTimeout(() => {
      if (login === 'admin' && password === '12345') {
        toast.success('Добро пожаловать, Администратор!');
        onLogin('admin');
      } else if (login === 'водитель' && password === '54321') {
        toast.success('Добро пожаловать!');
        onLogin('driver');
      } else {
        toast.error('Неверный логин или пароль', {
          description: 'Проверьте правильность введенных данных',
        });
      }
      setIsLoading(false);
    }, 800);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="space-y-4">
          <div className="text-center">
            <CardTitle className="text-blue-900">Вход в систему</CardTitle>
            <CardDescription>
              Введите ваш логин и пароль для продолжения
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="login" className="flex items-center gap-2">
                <Mail className="w-4 h-4" />
                Логин
              </Label>
              <Input
                id="login"
                type="text"
                placeholder="Номер телефона или почта"
                value={login}
                onChange={(e) => setLogin(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password" className="flex items-center gap-2">
                <Lock className="w-4 h-4" />
                Пароль
              </Label>
              <Input
                id="password"
                type="password"
                placeholder="Введите пароль"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>
            <Button
              type="submit"
              className="w-full bg-blue-600 hover:bg-blue-700"
              disabled={isLoading}
            >
              <LogIn className="w-4 h-4 mr-2" />
              {isLoading ? 'Вход...' : 'Войти'}
            </Button>
          </form>

          <div className="mt-4 pt-4 border-t">
            <p className="text-center text-gray-600 mb-3">
              Нет аккаунта?
            </p>
            <Button
              variant="outline"
              onClick={onRegister}
              className="w-full border-blue-600 text-blue-600 hover:bg-blue-50"
            >
              <UserPlus className="w-4 h-4 mr-2" />
              Зарегистрироваться
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}