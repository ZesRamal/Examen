# COBRATRON EXAMEN

Esta base de datos es para un sistema que mantiene registro de contratos de pagos a cierta cantidad de plazos (semanales, mensuales, trimestrales, semestrales o anuales). Tiene funciones que crean un nuevo contrato, otra que marca un pago nuevo de éste último y una última que genera un reporte de los pagos que faltan.

##### Contenido 
[Tablas](#tablas)  
[Ejecución](#ejecucion) 

<a name="tablas"/>
## Tablas

### Tabla Contracts

| Nombre de Columna          | Tipo de Dato           |
| -------------------------- | ---------------------- |
| **contract_id**            | `SERIAL` (Primary Key) |
| **client_name**            | `VARCHAR(255)`         |
| **start_date**             | `DATE`                 |
| **end_date**               | `DATE`                 |
| **total_amount**           | `DECIMAL(15, 2)`       |
| **payment_frequency**      | `VARCHAR(15)`          |
| **partial_payment_amount** | `DECIMAL(15, 2)`       |
| **next_due_date**          | `DATE`                 |
| **remaining_balance**      | `DECIMAL(15, 2)`       |
| **status**                 | `BOOLEAN`              |


### Tabla PaymentLogs

| Nombre de Columna    | Tipo de Dato           |
| -------------------- | ---------------------- |
| **payment_id**       | `SERIAL` (Primary Key) |
| **contract_id**      | `INT`                  |
| **payment_amount**   | `DECIMAL(15, 2)`       |
| **payment_due_date** | `DATE`                 |


## Relaciones

- **Contracts → PaymentLogs**:  
  Uno a muchos para `Contracts` y `PaymentLogs`. Cada contrato tiene asociado diferentes pagos. El `contract_id` en la tabla `PaymentLogs` es una foreign key que referencia el `contract_id` de la tabla `Contracts`.

---

<a name="ejecucion"/>
## Ejecución

### Prerequisitos

- Docker, si no cuentas con Docker en tu equipo te puedes guiarte con su documentación oficial:
  - [Instalar Docker 🐋](https://docs.docker.com/get-docker/)
  - [Instalar Docker Compose 🐳](https://docs.docker.com/compose/install/)

### Paso 1: Clona el Repositorio

Clona este repositorio en tu máquina local:

```bash
git clone https://github.com/ZesRamal/Cobratron-Examen.git
cd your-repository
```

### Paso 2: Configura el Docker

El archivo `docker-compose.yml` crea un contenedor PostgreSQL con configuraciones preestablecidas. Si deseas puedes modificar los siguientes parametros dentro del archivo pero recomiendo dejarlos como están.

**Parametros:**

- `POSTGRES_USER`: Define el usuario con el que se va a ingresar a la base de datos. (Predeterminado: `postgres`)
- `POSTGRES_PASSWORD`: Defines the password for the `postgres` user. (Predeterminado: `password`)
- `ports`: Mapea el puerto local `5645` al puerto `5432` de PostgreSQL dentro del contenedor. (Predeterminado: `5432:5432`)

### Paso 3: Inicializa el Contenedor

1. Abre una terminal de comandos y dirigete a la ubicación del archivo `docker-compose.yml`.
2. Corre el siguiente comando para levantar el contenedor:

   ```bash
   docker-compose up --build
   ```

   - Con `--build` indicamos que se vuelva a generar la imagen si realizamos algún cambio a `docker-compose.yml`.
   - Docker descarga la imagen de PostgreSQL si no la tienes.
   - Automaticamente corre el archivo SQL dentro de `init/` para crear la base de datos.
   - Puedes añadir `-d` para correr el contenedor en segundo plano.

### Paso 4: Conectarse a la Base de Datos

1. Dentro de la terminal de comandos escribimos lo siguiente:

   ```bash
   docker exec -it cobratron-db bash
   ```

   - Esto nos introducirá a la terminal del contenedor.

2. Ahora para conectarnos al servidor escribimos lo siguiente:

   ```bash
   psql -h localhost -U postgres -d cobratron -p 5432
   ```

   Después de esto se te pedirá la contraseña que se configuró anteriormente.

   **Parametros:**

   - `-h localhost`: Indica el host al que nos conectaremos.
   - `-U postgres`: Indica el usuario con el que nos conectamos (si se modificó `POSTGRES_USER` cambiarlo al correspondiente).
   - `-d cobratron`: Indica el nombre de la BD a conectarse.
   - `-p 5645`: Indica el puerto de conexión (si se modificó `ports` cambiarlo al correspondiente).

### Paso 5: Escribir Queries

Dentro de la herramienta psql podemos copiar y pegar los queries de la carpeta [queries 📄](/queries/) para ejecutar las diferentes funciones.

- [Añadir Cliente/Contrato ➕](/queries/new_client.sql): Función que añade un valor a la tabla de Contratos.
- [Registrar Pago 💵](/queries/make_payment.sql): Función que registra un pago de algun plazo de un contrato.
- [Obtener Reporte de Faltantes 📕](/queries/show_report.sql): Función que regresa una tabla de los pagos faltantes de un contrato con su monto y fecha.

- Si quieres consultar todos los contratos escribe:

```bash
   SELECT * from Contracts;
```

- Si quieres consultar todos los pagos escribe:

```bash
   SELECT * from PaymentLogs;
```

### Paso 6: Detener el Contenedor

En una consola local en la ubicación del `docker-compose.yml` escribe lo siguiente:

```bash
docker-compose down
```

Esto removerá y detendrá el contenedor.
