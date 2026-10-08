# SplitShellChain — Analiza Granic Statycznej Detekcji AV

## Overview

**SplitShellChain** to projekt badawczy (Proof of Concept) analizujący mechanizmy działania statycznych silników antywirusowych (AV) w kontekście analizy per-plik.

Projekt demonstruje ograniczenia sygnaturowej analizy statycznej: **ten sam kod PowerShell, klasyfikowany jako złośliwy w ramach pojedynczego pliku, omija detekcję statyczną po rozbiciu na sekwencyjny łańcuch fragmentów łączonych dynamicznie (dot-sourcing).** 

Eksperyment dowodzi konieczności stosowania wielowarstwowej architektury obronnej (*Defense-in-Depth*), opierającej się na detekcji behawioralnej i analizie w czasie rzeczywistym (AMSI, EDR).

> ⚠️ **Uwaga:** Narzędzie przeznaczone do celów badawczo-edukacyjnych. Uruchamiać wyłącznie w odizolowanym środowisku laboratoryjnym.

---

## Zakres i cele badania

Celem projektu jest usystematyzowanie wiedzy na temat granic detekcji plikowej oraz dostarczenie gotowych wniosków dla zespołów Blue Team/SOC.

### Kluczowe komponenty projektu:
1. **Automatyzacja podziału (`shellsplitter.py`):** Dedykowany parser składniowy rozbijający skrypty PowerShell na łańcuchy wykonawcze z zachowaniem spójności bloków (`try/catch`, `here-strings`, balans nawiasów klamrowych).
2. **Empiryczna weryfikacja:** Udokumentowany test porównawczy wykazujący różnicę w reakcji silnika AV w zależności od metody dostarczenia tego samego kodu.
3. **Modelowanie detekcji (Purple Team):** Opracowanie reguł detekcyjnych i wskaźników kompromitacji (IoC) pozwalających identyfikować technikę na poziomie logów i runtime.

---

## Wyniki eksperymentu

| Wariant dostarczenia | Plik / Łańcuch | Wynik detekcji statycznej |
| :--- | :--- | :--- |
| **Monolit (Oryginał)** | `invoke-powershelltcp.ps1` | 🔴 **Zablokowany** (Sygnatura statyczna) |
| **Łańcuch Dot-Source** | `output/line001.ps1 → ...` | 🟢 **Wykonany** (Brak reakcji skanera plikowego) |

Zmienną niezależną w badaniu był wyłącznie **sposób dostarczenia kodu**, przy zachowaniu pełnej tożsamości logiki operacyjnej payloadu.

---

## Analiza architektoniczna

Skuteczność techniki wynika z fundamentalnych ograniczeń projektowych statycznych skanerów plikowych, które analizują pliki w izolacji. Pełna rekonstrukcja grafu wywołań w trybie statycznym jest nieefektywna z trzech powodów:

1. **Problem zatrzymania (Nierozstrzygalność):** Dynamiczne ładowanie zależności za pomocą dot-sourcingu może zależeć od zmiennych środowiskowych lub zasobów sieciowych. Statyczna rekonstrukcja wymagałaby pełnej emulacji środowiska wykonawczego.
2. **Narzut wydajnościowy:** Głęboka emulacja i badanie powiązań każdego skryptu `.ps1` znacząco obniżyłaby wydajność systemu operacyjnego.
3. **Kwestia False Positives:** Łączenie modułów poprzez dot-sourcing jest standardowym wzorcem projektowym w środowiskach PowerShell (np. profile, moduły CI/CD). Agresywne flagowanie samych powiązań generowałoby wysoki poziom fałszywych alarmów.

---

## 🛡️ Wektor obronny (Detection & Mitigation)

Omijanie detekcji statycznej podkreśla kluczową rolę mechanizmów kontroli w warstwie wykonawczej (runtime):

### 1. Antimalware Scan Interface (AMSI)
AMSI przekazuje treść skryptu do skanera po jego zrekonstruowaniu w pamięci (post-deobfuscation). Niezależnie od liczby pośrednich plików, ostateczny blok kodu trafia do silnika oceniającego przed wykonaniem.

### 2. PowerShell Script Block Logging (Event ID 4104)
Włączenie szczegółowego logowania bloków kodu pozwala zarejestrować pełną treść wykonywanych fragmentów w Dzienniku Zdarzeń Windows, ujawniając sekwencję wywołań dot-source.

### 3. Sygnatury Behawioralne i Heurystyka
* **Anomalia plików:** Tworzenie i szybkie usuwanie serii jednoliniowych plików `.ps1` w krótkim odstępie czasu.
* **Wzorzec kodu:** Wykrywanie sekwencji kończących się wzorcem `. .\lineNNN.ps1`.
* **Korelacja procesów:** Monitorowanie procesu PowerShell wykonującego pętle ładowania plików z katalogów tymczasowych.

---

## Moduł rozdzielający (`shellsplitter.py`)

Skrypt `shellsplitter.py` odpowiada za parsowanie i podział kodu źródłowego:

```sh
python shellsplitter.py -i payload.ps1 -o output --chain --runner --delay 200
```

### Parametry konfiguracyjne:
* `--chain` — Generowanie sekwencyjnego łańcucha wywołań dot-source.
* `--runner` — Tworzenie pliku inicjującego (entrypoint).
* `--cleanup` — Dopisanie logiki czyszczenia poprzednich fragmentów po wykonaniu.
* `--delay` — Wprowadzenie opóźnienia (ms) między kolejnymi wywołaniami.
* `--duckify` — Generowanie skryptu uruchomieniowego dla urządzeń typu BadUSB (DuckyScript).

---

## Architektura repozytorium

```text
SplitShellChain-AV-Evasion/
├── shellsplitter.py              # Główny parser i generator łańcucha
├── invoke-powershelltcp/
│   ├── invoke-powershelltcp.ps1  # Próbka testowa (monolit)
│   ├── output/                   # Wygenerowany łańcuch wywołań (line001..033)
│   └── *.png                     # Materiały dowodowe z testów
└── keylogger/
    ├── keylogger.ps1             # Druga próbka testowa
    └── output/                   # Wygenerowany łańcuch wywołań
```

---

## Autor

**Adrian Jędrocha** (`salmontts`)  
*Cybersecurity Researcher & Developer*  
GitHub: [github.com/salmontts](https://github.com/salmontts)
