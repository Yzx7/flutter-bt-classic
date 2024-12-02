#include <SoftwareSerial.h>
#include <Servo.h>
#include <NewPing.h>

SoftwareSerial hc06(3, 2);

#define TRIG_PIN 13  //A0
#define ECHO_PIN 12  //A1
#define MAX_DISTANCE 100
#define IR_PIN 8
#define BTSTATE_PIN A5


// Motoreductores
#define IN1 10
#define IN2 9
#define IN3 7
#define IN4 4
// Motoreductores PWM
#define VR_PIN 5
#define VL_PIN 6

#define SERVO_PIN A2
#define LED_AUTOSTATUS_PIN 11




// const int Trigger = 13;  //Pin digital 2 para el Trigger del sensor
// const int Echo = 12;     //Pin digital 3 para el Echo del sensor
// long t;                  //tiempo que demora en llegar el eco
// long d;                  //distancia en centímetros


NewPing sonar(TRIG_PIN, ECHO_PIN, MAX_DISTANCE);
// char BtCode = '0';           //Define la lectura que hará el HC-05
byte BtCode = 0;
byte preBtCode = 0;
byte SelfDriving_force =8;
int DatoNum = 0;           //Define la lectura que hará el HC-05
byte time = 0;             //Define la lectura que hará el HC-05
unsigned int timeoff = 0;  //Define la lectura que hará el HC-05
const byte L_sMotor = 10;  //Señal para adelantar
const byte R_sMotor = 20;  //Señal para retroceder

int LED = 7;     //Define la activacion del LED
int Buzzer = 6;  //Define la activacion del Buzzer

struct Result {
  bool success;
  byte value;
};


Result resultA;
Result resultA2;
Result resultR;
Result resultR2;
Servo myservo;

float vecRL[2] = { 0, 0 };
float potencia = 0;
float potenciaR = 0;
float potenciaL = 0;

int distance = 100;


bool resIR = 0;

void SelfDrivingMode() {

  
  digitalWrite(LED_AUTOSTATUS_PIN, HIGH);
  int distanceR = 0;
  int distanceL = 0;
  //delay(40);

  if (distance <= 15) {
    // moveStop();
    // delay(100);
    // moveBackward();
    //Auto_Forward_Motor(-9,20);
    // Auto_Forward_Motor(-SelfDriving_force, 150);
    byte itersS = -SelfDriving_force*40+460;
    Auto_Forward_Motor(-SelfDriving_force, itersS);
    Auto_Forward_Motor(0, 5);
    delay(300);
    distanceR = lookRight();
    delay(200);
    distanceL = lookLeft();
    delay(200);

    // Serial.print(distanceR);
    // Serial.print(",");
    // Serial.print(distanceL);

    if (distanceR >= distanceL) {
      Auto_Right_Motor(SelfDriving_force, itersS);
      // Serial.print(",");
      // Serial.println("R");
    } else {
      Auto_Left_Motor(SelfDriving_force, itersS);
      // Serial.print(",");
      // Serial.println("L");
    }
  } else {
    Auto_Forward_Motor(SelfDriving_force, 10);
    // Auto_Forward_Motor(8,40);
    // moveForward();
  }
  distance = readPing();
  digitalWrite(LED_AUTOSTATUS_PIN, LOW);
  Auto_Forward_Motor(0, 1);

}

void setup() {
  pinMode(IN1, OUTPUT);  //Inicializa las salidas al driver 293
  pinMode(IN2, OUTPUT);  //...
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
  pinMode(VR_PIN, OUTPUT);
  pinMode(VL_PIN, OUTPUT);
  pinMode(IR_PIN, INPUT);
  pinMode(BTSTATE_PIN, INPUT);

  pinMode(LED_AUTOSTATUS_PIN, OUTPUT);
  
  myservo.attach(SERVO_PIN);
  myservo.write(115);
  digitalWrite(LED_AUTOSTATUS_PIN, HIGH);
  delay(2000);
  distance = readPing();
  delay(100);
  distance = readPing();
  delay(100);
  distance = readPing();
  delay(100);
  distance = readPing();
  delay(100);

  // pinMode(Trigger, OUTPUT);    //pin como salida
  // pinMode(Echo, INPUT);        //pin como entrada
  // digitalWrite(Trigger, LOW);  //Inicializamos el pin con 0

  Serial.begin(115200);
  digitalWrite(LED_AUTOSTATUS_PIN, LOW);
  Serial.println("ENTER AT Commands:");

  hc06.begin(9600);
}


// bool Comb(a byte, b byte, x byte, y byte, ) {
//   return (a == x && b == y) || (a == y && b == x)
// }
// bool Comb(a byte, b byte, x byte){
//   return a == x && b == x
// }

Result someRange10(byte a, byte b, byte x) {
  Result result;

  result.success = false;
  result.value = 0;

  if (a - x >= 0 && a - x < 10) {
    result.success = true;
    result.value = a - x;
  }


  if (b - x >= 0 && b - x < 10) {

    result.success = true;
    result.value = b - x;
  }
  return result;
}


void loop() {

  // resIR = digitalRead(IR_PIN);
  // Serial.print("IR:");
  //  Serial.println(resIR);

  if (hc06.available() > 0) {
    preBtCode = BtCode;
    BtCode = hc06.read();
    if(BtCode >=60 && BtCode <63){
      SelfDriving_force=BtCode-60+7;
      BtCode=52;
    }
    //Serial.println(BtCode);
  } else {

    if (timeoff > 30000 || (timeoff > 10000 && BtCode == 52)) {
      BtCode = 0;
      timeoff = 0;
    }
    timeoff++;
  }
   if (digitalRead(BTSTATE_PIN) == LOW) {

      digitalWrite(LED_AUTOSTATUS_PIN, HIGH);
      delay(100);
      digitalWrite(LED_AUTOSTATUS_PIN, LOW);
      delay(100);
      OFF_Motor();
      vecRL[0] = 0;
      vecRL[1] = 0;
      return;
    // Serial.println("HC-05 desconectado");
  } else{
      digitalWrite(LED_AUTOSTATUS_PIN, LOW);
  }
  

  if (BtCode == 2 || BtCode == 0) {
    OFF_Motor();
    vecRL[0] = 0;
    vecRL[1] = 0;
  }

  Serial.print("BtCode:");
   Serial.print(BtCode);
   Serial.print(",");

  if (BtCode == 52) {
    Serial.println("SelfDrivingMode");
    SelfDrivingMode();
    return;
  } else {
    digitalWrite(SERVO_PIN, HIGH);
  }

  resultA = someRange10(BtCode, preBtCode, L_sMotor);  // 10 - 19
  resultR = someRange10(BtCode, preBtCode, R_sMotor);  // 20 - 29

  resultA2 = someRange10(BtCode, preBtCode, L_sMotor + 20);  // 30 - 39
  resultR2 = someRange10(BtCode, preBtCode, R_sMotor + 20);  // 40 - 49

  resultA.value = 9 - resultA.value;
  resultA2.value = 9 - resultA2.value;
  if (resultA.success) {  //... avance del tractor
    vecRL[0] = resultA.value;
  }

  vecRL[1] = resultR.value;

  // digitalWrite(Trigger, HIGH);
  // delayMicroseconds(10);  //Enviamos un pulso de 10us
  // digitalWrite(Trigger, LOW);
  // d = digitalRead(Echo);
  // t = pulseIn(Echo, HIGH, 10000);  //obtenemos el ancho del pulso
  // d = t / 59;               //escalamos el tiempo a una distancia en cm


  if (resultA.success) {  //... avance del tractor

    if (resultR2.success) {
      potencia = sqrt(vecRL[0] * vecRL[0] + resultR2.value * resultR2.value);
      potencia *= -1;
    }
    if (resultA2.success) {
      potencia = sqrt(vecRL[0] * vecRL[0] + resultA2.value * resultA2.value);
    }

    // if (d < 20 && d>0 && potencia>0 ) {
    //   potencia *= d / 20;
    //   if (d < 5) {
    //     potencia = 0;
    //   }
    // }
    // A_Motor(resultA.value);  //...
    if (preBtCode == 2) {
      Right_Motor(9);  //...
      Right_Motor(0);  //...
    }
    potenciaL = resultA.value + 9;
    potenciaR = 18 - potenciaL;
    potenciaR /= potenciaL;
    potenciaR *= potencia;
    potenciaL = potencia;

    // Left_Motor(potenciaL);   //...
    // Right_Motor(potenciaR);  //...
    //myservo.write(90);
    Right_Motor(potenciaL);  //...
    Left_Motor(potenciaR);   //...
  }

  // if (resultR.success) {  //... avance del tractor
  //                         // R_Motor(resultR.value);  //...
  //   if (preBtCode == 2) {
  //     Left_Motor(0);  //...
  //     Left_Motor(9);  //...
  //   }
  //   Right_Motor(resultR.value);  //...
  // }


  if (resultR.success) {  //... avance del tractor

    if (resultR2.success) {
      potencia = sqrt(vecRL[1] * vecRL[1] + resultR2.value * resultR2.value);
      potencia *= -1;
    }
    if (resultA2.success) {
      potencia = sqrt(vecRL[1] * vecRL[1] + resultA2.value * resultA2.value);
    }

    // if (d < 20 && d>0 && potencia>0) {
    //   potencia *= d / 20;
    //   if (d < 5) {
    //     potencia = 0;
    //   }
    // }

    // A_Motor(resultA.value);  //...
    if (preBtCode == 2) {
      Left_Motor(9);  //...
      Left_Motor(0);  //...
    }
    potenciaR = resultR.value + 9;
    potenciaL = 18 - potenciaR;
    potenciaL /= potenciaR;
    potenciaL *= potencia;
    potenciaR = potencia;
    //myservo.write(90);
    Right_Motor(potenciaL);  //...
    Left_Motor(potenciaR);   //...
  }
  // Serial.print(vecRL[0]);
  // Serial.print(",");
  // Serial.print(vecRL[1]);
  // Serial.print(",");

  // Serial.println(d);
  // Serial.print(potencia);
  // Serial.print(",");
  // Serial.print(potenciaL);
  // Serial.print(",");
  // Serial.println(potenciaR);
  time++;
  time %= 100;
  Serial.println("");
}

void Right_Motor(float vel) {  //Funcion para el giro a la derecha

  float result;
  // digitalWrite(IN1, HIGH);
  // digitalWrite(IN2, LOW);
  if (vel >= 0) {

    digitalWrite(IN1, HIGH);
    digitalWrite(IN2, LOW);
  } else {
    digitalWrite(IN1, LOW);
    digitalWrite(IN2, HIGH);
  }

  // result = (float)vel;
  // result -= 4.5;
  result = abs(vel) / 9;
  int absValue = (int)(result * 255);
  // Serial.println();
  // Serial.print("RMotor: ");
  // Serial.println(absValue);
  // Serial.print("R:");
  // Serial.print(absValue);
  // Serial.print(",");
  analogWrite(VR_PIN, min(absValue, 255));
}

void Left_Motor(float vel) {  //Funcion para el giro a la derecha

  float result;
  // result = (float)vel;

  // digitalWrite(IN3, HIGH);
  // digitalWrite(IN4, LOW);
  if (vel >= 0) {

    digitalWrite(IN3, HIGH);
    digitalWrite(IN4, LOW);
  } else {
    digitalWrite(IN3, LOW);
    digitalWrite(IN4, HIGH);
  }


  // result -= 4.5;
  result = abs(vel) / 9;
  int absValue = (int)(result * 255);

  // Serial.print("L:");
  // Serial.print(absValue);
  // Serial.print(",");

  analogWrite(VL_PIN, min(absValue, 255));
}

void Auto_Left_Motor(float vel, byte i) {  //Funcion para el giro a la derecha
    Left_Motor(vel);
    Right_Motor(-vel);
  for (byte x = 0; x < i; x++) {
    delay(3);
  }
}
void Auto_Right_Motor(float vel, byte i) {  //Funcion para el giro a la derecha
    Right_Motor(vel);
    Left_Motor(-vel);

  for (byte x = 0; x < i; x++) {
    delay(3);
  }
}

void Auto_Forward_Motor(float vel, byte i) {  //Funcion para el giro a la derecha
  Left_Motor(vel);
  Right_Motor(vel);
  for (byte x = 0; x < i; x++) {
    delay(3);
  }
}

void D_Motor() {  //Funcion para el giro a la derecha
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
}

void I_Motor() {  //Funcion para el giro a la izquierda
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
}

void A_Motor() {  //Funcion para el avance del tractor
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
}

void R_Motor() {  //Funcion para el retroceso del tractor
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
}

void OFF_Motor() {  //Funcion para apagar el movimiento (Se tiene que activar cuando ninguna señal se envie)
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
}
void A_LED() {  //Funcion para activar los LEDs por 0.5s
  digitalWrite(LED, HIGH);
  delay(500);
  digitalWrite(LED, LOW);
}

void A_Buzzer() {  //Funcion para activar el buzzer por 0.2s
  digitalWrite(Buzzer, HIGH);
  delay(200);
  digitalWrite(Buzzer, LOW);
}


int readPing() {
  delay(70);
  int cm = sonar.ping_cm();
  if (cm == 0) {
    cm = 250;
  }
  return cm;
}
int lookRight() {
  myservo.write(50);
  delay(500);
  int distance = readPing();
  delay(100);
  myservo.write(115);
  return distance;
}

int lookLeft() {
  myservo.write(170);
  delay(500);
  int distance = readPing();
  delay(100);
  myservo.write(115);
  return distance;
  delay(100);
}
