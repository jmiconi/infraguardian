# Imagen base de Python
FROM python:3.11

# Carpeta de trabajo dentro del container
WORKDIR /app

# Copiamos dependencias
COPY requirements.txt .

# Instalamos dependencias
RUN pip install -r requirements.txt

# Copiamos el código
COPY collector.py .

# Ejecutar script al iniciar container
CMD ["python", "collector.py"]
