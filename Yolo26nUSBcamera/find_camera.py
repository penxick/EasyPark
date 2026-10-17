
import cv2

# Поиск рабочей USB-камеры среди доступных устройств

for index in range(10):
    camera = cv2.VideoCapture(index, cv2.CAP_MSMF)

    if not camera.isOpened():
        camera.release()
        continue

    print(f"Проверяем камеру {index}")

    for _ in range(10):
        camera.read()

    while True:
        success, frame = camera.read()

        if not success:
            print(f"Камера {index}: нет изображения")
            break

        cv2.putText(
            frame,
            f"CAMERA INDEX: {index}",
            (20, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 255, 0),
            2
        )

        cv2.imshow("Camera Test", frame)

        key = cv2.waitKey(30) & 0xFF

        # N — проверить следующую камеру
        if key == ord("n"):
            break

        # Q — завершить поиск
        if key == ord("q"):
            camera.release()
            cv2.destroyAllWindows()
            raise SystemExit

    camera.release()
    cv2.destroyAllWindows()

print("Поиск завершён")
