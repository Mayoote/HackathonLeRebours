// Programme de test : Arduino UNO <-> Godot (projet test-communication-arduino)
const int LED_PIN = 13;                  // LED et sa résistance de 220 ohms
const int BOUTON_PIN = 2;                // bouton relié au GND

bool appaire = false;                    // vrai une fois que Godot a trouvé la carte
bool boutonAvant = false;                // l'état du bouton au tour précédent

void setup() {
  Serial.begin(115200);                  // la vitesse attendue par Godot
  pinMode(LED_PIN, OUTPUT);
  pinMode(BOUTON_PIN, INPUT_PULLUP);     // HIGH au repos, LOW quand on appuie
}

void loop() {
  if (Serial.available() > 0) {
    String message = Serial.readStringUntil('\n'); // une ligne reçue de Godot
    message.trim();                                // retire le \r éventuel
    if (message == "DISCOVER") {                   // Godot cherche la carte
      Serial.println("GDSERIAL_ACK:arduino_uno");  // la carte se présente
      appaire = true;
    } else if (appaire) {
      traiter(message);                            // une commande de Godot
    }
  }

  if (appaire) {
    bool appuye = (digitalRead(BOUTON_PIN) == LOW);
    if (appuye != boutonAvant) {                   // seulement quand il change
      boutonAvant = appuye;
      Serial.println(appuye ? "button:1" : "button:0");
    }
  }
}

// Une commande de Godot a la forme cle:valeur, par exemple led:1
void traiter(const String& message) {
  int deuxPoints = message.indexOf(':');           // où commence la valeur
  if (deuxPoints == -1) return;                    // pas de deux-points : on ignore
  String cle = message.substring(0, deuxPoints);
  String valeur = message.substring(deuxPoints + 1);

  if (cle == "led") {
    digitalWrite(LED_PIN, valeur == "1" ? HIGH : LOW); // led:1 allume, led:0 éteint
    Serial.println("ack:led:" + valeur);               // accusé de réception
  } else if (cle == "ping") {
    Serial.println("pong:" + valeur);                  // Godot mesure l'aller-retour
  }
}
