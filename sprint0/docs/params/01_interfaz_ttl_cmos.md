# Epic 1 — Caracterización de la interfaz TTL-CMOS



## User Story 1.1 — Interfaz directa CMOS → TTL


### 1. Objetivo
Construir y medir con osciloscopio la conexión entre
una salida CMOS (74HC00) y una entrada TTL (74LS00).

### 2. Materiales y equipo
- Protoboard y cables de conexión.
- Batería de 9 V.
- NAND CMOS 74HC00.
- NAND TTL 74LS00.
- Potenciómetro de precisión de 100 Ω W101.
- Regulador de tensión de 5 V LM7805.
- Multímetro digital.
- Osciloscopio Fnirsi-1013D.
- Resistencias de 66 kΩ y 100 kΩ.

### 3. Parámetros eléctricos
- Vcc = 5 V. 

### 4. Esquema del circuito

![circuito de la user story 1.1 en LTspice](no_buffer_circuit_schematic_LTspice.png)

*Figura 1. Circuito de interfaz CMOS a TTL sin buffer en LTspice.*

### 5. Montaje físico

![Foto del circuito de la user story 1.1 en protoboard](no_buffer_cmos-ttl_interface_0.jpg)

*Figura 2. Fotografía del circuito de interfaz CMOS a TTL sin buffer.*

![Foto cenital del circuito de la user story 1.1 en protoboard](no_buffer_cmos-ttl_interface_1.jpg)

*Figura 3. Fotografía cenital del circuito de interfaz CMOS a TTL sin buffer.*

![Foto del circuito de la user story 1.1 junto al osciloscopio](no_buffer_cmos-ttl_interface_with_oscilloscope.jpg)

*Figura 4. Fotografía del circuito de interfaz CMOS a TTL junto al osciloscopio.*




### 6. Resultados de la simulación
La simulación muestra los valores de la tensión en el nodo de interfaz (salida de la NAND CMOS)
y en la salida de la NAND TTL con una resistencia de carga en la interfaz de 1 kΩ.


![Gráfica de LTspice de us 1.1](no_buffer_simulation_stable.png)

*Figura 5. Gráfica de tensión contra tiempo de la tensión de interfaz y de la salida del circuito (NAND TTL) en LTspice.*

### 7. Medición con el osciloscopio
Se capturó con el osciloscopio el valor de CD estático de las mismas dos señales.

![Gráfica del multímetro us 1.1](no_buffer_osciloscope_stable.png)

*Figura 6. Resultado del osciloscopio de las tensiones en ambas compuertas. El canal 1 (en amarillo) muestra la tensión de salida de la NAND TTL; y el canal 2 (en celeste), la de la NAND CMOS.*

<!-- 
## User Story 1.2 — Simulación de carga (Fan-Out)

### 1. Objetivo
Capturar con el osciloscopio y en simulación la degradación de señal que
provoca el fallo lógico en la compuerta TTL.

### 2. Materiales y equipo
- Protoboard y cables de conexión.
- Batería de 9 V.
- NAND CMOS 74HC00.
- NAND TTL 74LS00.
- Potenciómetro de precisión de 100 Ω W101.
- Regulador de tensión de 5 V LM7805.
- Multímetro digital.
- Osciloscopio Fnirsi-1013D.
- Resistencias de 66 kΩ y 100 kΩ.

### 3. Parámetros eléctricos
- Vcc = 5 V.
- La resistencia del potenciómetro varió de 100 Ω a 40 Ω.


### 4. Resultados de la simulación
La simulación realiza un barrido en el valor de la resistencia de 1 kΩ a 0 Ω
mientras muestra los valores de la tensión en el nodo de interfaz (salida de la NAND CMOS)
y en la salida de la NAND TTL.


![Gráfica de LTspice de us 1.1](no_buffer_circuit_simulation_plot_LTspice.png)

*Figura 7. Gráfica de tensión contra tiempo de la tensión de interfaz y de la salida del circuito (NAND TTL) en LTspice.*



### 5. Medición con el osciloscopio
Se capturó con el osciloscopio la degradación de la salida con dos escalas de tiempo.
En un caso se usó una escala de 2s/división para capturar el proceso completo de aumento en la tensión nivel bajo de la NAND CMOS;
y seguidmante, una escala de 200ms/división para capturar la degradación de la señal únicamente y con mayor detalle.
Además del osciloscopio se utilizó un multímetro digital para precisar la tensión de la NAND CMOS 
y el valor de resistencia del potenciómetro que producen la ruptura de la señal.

![Gráfica del multímetro us 1.1](no_buffer_ttl_logic_failure_2s_per_div.png)

*Figura 8. Resultado del osciloscopio con 2s/división.*

![Gráfica del multímetro us 1.1](no_buffer_ttl_logic_failure_close_up.png)

*Figura 9. Resultado del osciloscopio con 200ms/división.*

### 6. Resultados de la medición
- Se encontró con el multímetro que la tensión en la NAND CMOS que causa la degradación de la señal en la NAND TTL fue de 2,39 V.
    - La medición del osciloscopio apoya esta medición ya que oscila alrededor de ese valor como se observa en la figura 6.
- Se encontró que la resistencia del potenciómetro en este mismo punto fue de 42,3 Ω.


### 7. Conclusiones de User Story 1.1
La tensión y resistencia encontradas en la simulación y la medición se comparan en la siguiente tabla
| Componente | Simulado | Medido |Error  |
|-----------|-------|------|----|
| Potenciómetro (Ω) | 53,3   | 42,3    |21%    |
| NAND CMOS (V)| 2,50     |2,39    |4%    |

La principal fuente de discrepancia es el comportamiento altamente ideal de la compuerta 74LS00 (NAND TTL) en LTspice, 
mientras que la compuerta medida muestra un comportamiento más irregular en la zona prohibida.
 -->
