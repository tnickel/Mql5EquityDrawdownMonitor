# Equity Drawdown Monitor - Dokumentation

## Überblick

Der **Equity Drawdown Monitor** ist ein MQL5 Expert Advisor (EA), der die Equity und Drawdowns für einzelne Magic Numbers in Echtzeit überwacht. Das Tool ermöglicht es Ihnen, mehrere Handelsstrategien (identifiziert durch Magic Numbers) unabhängig voneinander zu tracken und bei kritischen Drawdown-Levels visuell gewarnt zu werden.

## Hauptfunktionen

### 1. Automatische Magic Number-Erkennung

Der EA scannt automatisch Ihre Handelshistorie und erkennt alle Magic Numbers, die in den letzten N Tagen aktiv waren.

- **Konfigurierbar**: `InpLookbackDays` (Standard: 60 Tage)
- **Automatisch**: Kein manuelles Eintragen von Magic Numbers erforderlich
- **Dynamisch**: Bei jedem Neustart werden die aktuellen Magic Numbers erkannt

### 2. Unabhängige Equity-Berechnung pro Magic Number

Jede Magic Number wird **völlig unabhängig** überwacht:

- **Realized Profit**: Summe aller geschlossenen Trades für diese Magic
- **Floating Profit**: Gewinn/Verlust aller aktuell offenen Positionen
- **Total Equity**: Realized + Floating

**Wichtig**: Die Equity von Magic 0 beeinflusst NICHT die Berechnung von Magic 1, usw.

### 3. High Water Mark Drawdown-Tracking

Der EA verwendet die **High Water Mark**-Methode zur Drawdown-Berechnung:

- **High Water Mark**: Der höchste Equity-Wert, den eine Magic Number jemals erreicht hat
- **Current Drawdown**: Differenz zwischen High Water Mark und aktueller Equity
- **Max Drawdown**: Der größte Drawdown, der jemals beobachtet wurde

**Beispiel:**
```
Magic 0 startet bei Equity: -4000 → High Water Mark = -4000
Equity steigt auf +1000 → High Water Mark = +1000
Equity fällt auf +500 → Current Drawdown = 1000 - 500 = 500
Equity steigt auf +1200 → High Water Mark = +1200, Current Drawdown = 0
```

### 4. Prozentuale Drawdown-Berechnung

Alle Drawdowns werden als **Prozentsatz des Account Balance** angezeigt:

```
Drawdown% = (Current Drawdown / Account Balance) × 100
```

**Vorteil**: Ermöglicht einen fairen Vergleich zwischen verschiedenen Strategien, unabhängig von ihrer absoluten Equity.

### 5. Konfigurierbare Drawdown-Limits mit Farbcodierung

Sie können für bis zu **20 Magic Numbers** individuelle Drawdown-Limits festlegen:

#### Konfiguration
- **Format**: `"MagicNumber,MaxDrawdown"` 
- **Beispiel**: `"0,5"` bedeutet Magic 0 hat ein Limit von 5%
- **Parameter**: `InpCheck1` bis `InpCheck20`

#### Visuelle Warnung durch Farbcodierung

Die Zeilen ändern ihre Farbe basierend auf dem Verhältnis von aktuellem Drawdown zum konfigurierten Limit:

| Farbe | Bedingung | Bedeutung |
|-------|-----------|-----------|
| **WEISS** | DD% < 80% vom Limit | Normaler Betrieb |
| **GELB** | DD% ≥ 80% vom Limit | Vorsicht - Annäherung an Limit |
| **ORANGE** | DD% ≥ 90% vom Limit | Warnung - Nahe am Limit |
| **ROT** | DD% ≥ 100% vom Limit | GEFAHR - Limit erreicht oder überschritten! |

**Beispiel:**
- Konfiguriertes Limit: 5.0%
- Aktueller Drawdown: 4.0%
- Verhältnis: 4.0 / 5.0 = 80% → **GELB**

### 6. Optimierte Performance durch Inkrementelles Scanning

Der EA ist für **maximale Effizienz** optimiert:

- **Initialisierung**: Vollständiger Scan der Historie beim Start
- **Laufzeitupdate**: Nur neue Deals seit dem letzten Update werden gescannt
- **Timer-basiert**: Updates erfolgen nur alle N Sekunden (konfigurierbar), nicht bei jedem Tick

**Technische Details:**
```mql5
// Speichert letztes verarbeitetes Deal
m_last_deal_ticket

// Speichert letzte verarbeitete Zeit
m_last_history_time

// Scannt nur neue Deals
ProcessHistory(m_last_history_time, TimeCurrent())
```

### 8. Emergency Stop bei Drawdown-Überschreitung

Wenn der Drawdown das konfigurierte Limit erreicht, wird automatisch ein **Emergency Stop** ausgelöst:

- **Alle Positionen schließen**: Alle offenen Trades der betroffenen Magic Number werden sofort geschlossen
- **MessageBox Alarm**: Ein Popup informiert Sie über den Emergency Stop
- **E-Mail Benachrichtigung**: Eine E-Mail wird versendet (SMTP-Konfiguration in MT5 erforderlich)
- **Global Variable**: `EDM_STOP_MAGIC_{Magic}` wird auf 1 gesetzt
- **Status-Anzeige**: Die Zeile zeigt "STOPPED" in der Status-Spalte

**Konfiguration**: `InpEnableAutoStop` (Standard: true)

### 9. Manueller Reset

Ein gestoppter Robot kann wieder aktiviert werden:

1. Drücken Sie **F3** in MT5 (Globale Variablen)
2. Suchen Sie `EDM_STOP_MAGIC_12345` (Ihre Magic Number)
3. **Löschen** Sie den Eintrag
4. Der Monitor erkennt das automatisch und setzt den Status zurück auf "ACTIVE"

### 10. Chart-Info Logging

Beim Start des EAs werden alle offenen Charts im Log protokolliert:

```
=== Chart Information ===
Chart ID: 131234567890 | Symbol: EURUSD | Period: PERIOD_H1
   -> Objects: 150 | Types: OBJ_LABEL, OBJ_BUTTON, OBJ_TREND
=========================
```

Dies hilft bei der Identifizierung aktiver EAs auf verschiedenen Charts.

### 7. Interaktiver Info-Button

Ein **"?"** Button rechts oben öffnet eine Hilfe-Erklärung:

- **Klick 1**: Hilfe wird angezeigt (Tabelle wird ausgeblendet)
- **Klick 2**: Zurück zur Tabelle

Die Position der Hilfe ist konfigurierbar: `InpHelpXPosition` (Standard: 950px)

## Dashboard-Spalten Erklärt

### Magic
Die Magic Number der Strategie (z.B. 0, 12345, 67890)

### Realzd (Realized Profit)
- Summe **aller geschlossenen Trades** für diese Magic
- Beinhaltet: Profit, Commission, Swap
- Ändert sich nur wenn ein Trade geschlossen wird

### Float (Floating Profit)
- Gewinn/Verlust **aller offenen Positionen**
- Ändert sich in Echtzeit mit Marktbewegungen
- Wird zu "Realzd" wenn die Position geschlossen wird

### Equity
- **Gesamtstand** der Strategie
- Berechnung: `Equity = Realzd + Float`
- Zeigt den "wahren" aktuellen Wert der Strategie

### DD% (Current Drawdown %)
- **Aktueller Abstand** vom highest Equity-Punkt
- Berechnung: `((Max Equity - Current Equity) / Account Balance) × 100`
- **0%** = Sie sind am höchsten Punkt (High Water Mark)
- **>0%** = Sie sind unter dem höchsten Punkt gefallen

### MaxDD% (Maximum Drawdown %)
- Der **größte Drawdown**, der jemals beobachtet wurde
- Wird nie kleiner, nur größer wenn ein neuer Rekord-Drawdown erreicht wird
- Indikator für das "worst-case" Szenario dieser Strategie

### MaxAlw (Maximum Allowed)
- Das **konfigurierte Drawdown-Limit**
- Wird als Prozentsatz angezeigt
- **"--"** wenn kein Limit konfiguriert ist

### Status
- **ACTIVE**: Normale Überwachung aktiv
- **STOPPED**: Emergency Stop wurde ausgelöst
- Zeile wird **GRAU** wenn Status = STOPPED

## Konfigurationsparameter

### InpLookbackDays
- **Typ**: Integer
- **Standard**: 60
- **Beschreibung**: Anzahl der Tage, die für die Auto-Discovery von Magic Numbers gescannt werden

### InpRefreshRateSeconds
- **Typ**: Integer
- **Standard**: 1
- **Beschreibung**: Aktualisierungsintervall in Sekunden (wie oft das Dashboard aktualisiert wird)

### InpHelpXPosition
- **Typ**: Integer
- **Standard**: 950
- **Beschreibung**: Horizontale Position des Hilfe-Textes in Pixeln

### InpCheck1 bis InpCheck20
- **Typ**: String
- **Standard**: "" (leer)
- **Format**: `"MagicNumber,MaxDrawdown"`
- **Beispiel**: `"12345,3.5"` = Magic 12345 hat ein Limit von 3.5%
- **Beschreibung**: Konfigurierbare Drawdown-Limits für bis zu 20 Magic Numbers

### InpEnableAutoStop
- **Typ**: Bool
- **Standard**: true
- **Beschreibung**: Aktiviert/Deaktiviert den Emergency Stop bei Limit-Überschreitung

## Installation & Verwendung

### 1. Installation
1. Kopieren Sie `EquityDrawdownMonitor.mq5` nach `MQL5/Experts/`
2. Öffnen Sie MetaEditor und kompilieren Sie die Datei

### 2. Aktivierung
1. Öffnen Sie einen beliebigen Chart in MT5
2. Ziehen Sie den EA auf den Chart
3. Konfigurieren Sie die Parameter (siehe oben)
4. Stellen Sie sicher, dass "Algo Trading" aktiviert ist

### 3. Drawdown-Limits konfigurieren (Optional)

**Beispiel-Konfiguration:**
```
InpCheck1 = "0,5.0"        // Magic 0: Max 5% Drawdown
InpCheck2 = "12345,3.0"    // Magic 12345: Max 3% Drawdown
InpCheck3 = "67890,10.0"   // Magic 67890: Max 10% Drawdown
```

### 4. Interpretation der Anzeige

**Szenario 1: Gesunde Strategie**
```
Magic: 12345
Realzd: 5000.0
Float: 250.0
Equity: 5250.0
DD%: 0.5%
MaxDD%: 2.1%
MaxAlw: 5.0%
Farbe: WEISS ✓
```
→ Strategie ist profitabel, minimaler Drawdown, weit unter dem Limit

**Szenario 2: Warnung**
```
Magic: 67890
Realzd: 1000.0
Float: -500.0
Equity: 500.0
DD%: 4.2%
MaxDD%: 4.5%
MaxAlw: 5.0%
Farbe: GELB ⚠
```
→ Drawdown bei 84% des Limits (4.2/5.0), Vorsicht geboten!

**Szenario 3: GEFAHR**
```
Magic: 99999
Realzd: -2000.0
Float: -300.0
Equity: -2300.0
DD%: 5.5%
MaxDD%: 6.0%
MaxAlw: 5.0%
Farbe: ROT 🚨
```
→ Limit überschritten! Strategie sollte überprüft oder gestoppt werden!

## Häufig gestellte Fragen (FAQ)

### Warum zeigt DD% einen Wert > 0%, obwohl ich im Gewinn bin?

Der Drawdown wird **relativ zum höchsten Punkt** berechnet, nicht zum Startwert.

**Beispiel:**
- Sie starten bei +1000
- Steigen auf +2000 (High Water Mark)
- Fallen zurück auf +1500
- DD% = (2000 - 1500) / Account Balance = Positiv!

→ Sie sind zwar im Gewinn, aber **unter** Ihrem bisherigen Höchststand.

### Beeinflusst der Gewinn von Magic 1 den Drawdown von Magic 0?

**NEIN!** Jede Magic Number ist völlig unabhängig:
- Eigene Equity
- Eigener High Water Mark
- Eigener Drawdown

### Warum ist MaxDD% oft größer als DD%?

**MaxDD%** zeigt den **schlimmsten** Drawdown in der Historie, während **DD%** den **aktuellen** Drawdown zeigt.

**Beispiel:**
- Vor 2 Wochen: DD war 8% → MaxDD = 8%
- Heute: DD ist nur 2%
- MaxDD bleibt bei 8% (historisches Maximum)

### Kann ich Magic Numbers manuell hinzufügen?

Nein, die Auto-Discovery ist der einzige Weg. Wenn Sie eine neue Strategie starten möchten:
1. Führen Sie mindestens einen Trade mit der gewünschten Magic Number aus
2. Warten Sie bis die Lookback-Periode diese Trade erfasst (max. InpLookbackDays)
3. Starten Sie den EA neu → Magic wird erkannt

### Was passiert wenn ich keine Limits konfiguriere?

- Spalte "MaxAlw" zeigt **"--"**
- Zeilen bleiben immer **WEISS**
- Keine Farbwarnungen
- Monitoring funktioniert trotzdem vollständig

## Technische Details

### Architektur

```
CMagicMonitor (Klasse)
├── m_magic                 // Magic Number
├── m_realized_profit       // Summe geschlossener Trades
├── m_floating_profit       // Aktuell offene Positionen
├── m_current_equity        // Realized + Floating
├── m_max_equity            // High Water Mark
├── m_current_drawdown      // Max - Current Equity
├── m_max_drawdown          // Größter Drawdown ever
└── m_max_allowed_drawdown  // Konfiguriertes Limit
```

### Event-Handler

- **OnInit()**: Auto-Discovery, Initialisierung
- **OnTimer()**: Regelmäßige Updates (jede N Sekunden)
- **OnTick()**: Leer (Performance-Optimierung)
- **OnChartEvent()**: Info-Button Klick-Behandlung
- **OnDeinit()**: Aufräumen der grafischen Objekte

### Grafische Objekte

- **OBJ_LABEL**: Für alle Textanzeigen
- **OBJ_BUTTON**: Für den Info-Button
- **Prefix**: Alle Objekte beginnen mit "EDM_" für einfaches Cleanup

## Troubleshooting

### Dashboard wird nicht angezeigt
- Prüfen Sie, ob "Algo Trading" aktiviert ist
- Prüfen Sie die Experts-Log für Fehlermeldungen
- Stellen Sie sicher, dass der EA kompiliert wurde

### "Discovered 0 magic numbers"
- Keine Trades in den letzten `InpLookbackDays` Tagen
- Erhöhen Sie `InpLookbackDays`
- Führen Sie mindestens einen Trade aus

### Farbcodierung funktioniert nicht
- Prüfen Sie, ob Sie `InpCheckX` korrekt konfiguriert haben
- Format muss exakt sein: `"MagicNumber,MaxDD"` (z.B. `"12345,5.0"`)
- Keine Leerzeichen!

### Hilfe-Text überlappt mit Tabelle
- Erhöhen Sie `InpHelpXPosition` (z.B. auf 1100 oder 1200)
- Abhängig von Ihrer Bildschirmauflösung

## Lizenz & Support

**Entwickelt von**: AntiGravity Assistant  
**Version**: 1.10  
**Lizenz**: [Ihre Lizenz hier]

Für Support und Fragen, bitte erstellen Sie ein Issue im Repository.
