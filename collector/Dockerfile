# Imagen base de Python
FROM python:3.11-slim

# Evitar archivos .pyc y forzar logs sin buffer
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Carpeta de trabajo dentro del container
WORKDIR /app

# Copiamos dependencias
COPY requirements.txt .

# Instalamos dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copiamos el código del collector
COPY collector.py .

# Ejecutar script al iniciar container
CMD ["python", "collector.py"]
