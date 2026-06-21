# SplitShellChain — badanie granic detekcji statycznej

## TL;DR

PoC pokazujący, że **ten sam payload PowerShell — wykryty jako złośliwy w jednym
pliku — przestaje być flagowany, gdy rozbić go na łańcuch jednoliniowych
fragmentów łączonych przez dot-sourcing.** Kod się nie zmienia; zmienia się
*sposób* jego dostarczenia. To praktyczna ilustracja fundamentalnego
ograniczenia detekcji statycznej opartej na sygnaturach per-plik — i argument
za tym, dlaczego nowoczesna obrona musi działać w warstwie runtime (AMSI, EDR
behawioralny).

> ⚠️ Materiał badawczo-edukacyjny. Reverse shell i keylogger to publicznie
> dostępne payloady użyte jako próbki testowe. Uruchamiać wyłącznie we własnym,
> izolowanym labie.

---

## Co to faktycznie pokazuje (uczciwie)

To **nie jest 0-day ani nieznana technika.** Dzielenie payloadu i dot-sourcing
to znana rodzina metod obfuskacji (MITRE **T1027** — Obfuscated/Compressed
Files, **T1059.001** — PowerShell). Defenderzy znają ją od lat.

**Mój wkład** to nie odkrycie techniki, tylko:
1. **Automatyzacja** — `shellsplitter.py` tnie dowolny skrypt PowerShell na
   fragmenty z poprawną obsługą bloków (here-stringi, try/catch, balansowanie
   nawiasów), generuje łańcuch i runner.
2. **Czysta demonstracja eksperymentalna** — ten sam payload, dwa sposoby
   wykonania, udokumentowana różnica w detekcji. Kontrolowany eksperyment, nie
   przypadkowy bypass.
3. **Analiza *dlaczego* to działa** — i co to znaczy dla obrony (niżej).

Wartość tej pracy jest w **zrozumieniu granicy detekcji**, nie w "ominięciu
antywirusa".

---

## Eksperyment

| Wariant | Plik | Wynik |
|---------|------|-------|
| Oryginał (z publicznego źródła) | `invoke-powershelltcp.ps1` | 🔴 Defender blokuje natychmiast |
| Ten sam payload, pocięty łańcuchem | `output/line001.ps1 → …` | 🟢 brak alertu, wykonanie przechodzi |

Zmienną jest **wyłącznie sposób dostarczenia.** Logika payloadu identyczna.
To czyni z tego kontrolowany eksperyment nad zachowaniem silnika detekcji, a nie
po prostu "działający bypass".

(Zrzuty: `invoke-powershelltcp/invokeps1tcp_1.png` — blokada oryginału;
`invokeps1tcp_2.png` — wykonanie łańcucha.)

---

## Dlaczego to działa — i dlaczego to NIE jest "bug Defendera"

To kluczowa część, i to ona odróżnia tę pracę od "patrzcie, ominąłem AV".

Skanery statyczne analizują **pojedyncze pliki/skrypty**. Nie rekonstruują
pełnego grafu wykonania rozłożonego na łańcuch dot-source — i **nie mogą tego
robić w ogólności**, z trzech fundamentalnych powodów:

1. **Nierozstrzygalność.** Dot-source może ładować pliki warunkowo, z sieci,
   generowane w runtime. Żeby "skleić łańcuch w całość", skaner musiałby
   *wykonać dowolny kod*, by wiedzieć, co się sklei. To problem zatrzymania.
2. **Wydajność.** Pełna emulacja każdego skryptu z rozwijaniem wszystkich
   `. .\x.ps1` byłaby zabójcza dla wydajności każdej maszyny.
3. **Fałszywe pozytywy.** Legalne frameworki (buildy, profile PowerShell,
   ładowanie modułów) używają dot-source dokładnie tak samo. Agresywne sklejanie
   = zalanie użytkowników FP.

Dlatego Microsoft słusznie odpowiedział, że to **nie kwalifikuje się jako bug** —
to świadomy trade-off architektury detekcji statycznej, nie luka. I właśnie
dlatego istnieją **warstwy runtime**:

- **AMSI** (Antimalware Scan Interface) — przechwytuje kod PowerShell **w
  momencie wykonania**, po rekonstrukcji w pamięci, niezależnie od tego, na ile
  plików go pokrojono.
- **EDR behawioralny** — wykrywa *zachowanie* (otwarcie socketu, hook klawiatury,
  spawn reverse shella), nie sygnaturę pliku.

Mój łańcuch omija sygnatury **statyczne** — ale dobrze skonfigurowany AMSI +
EDR złapałby ten payload w runtime. To dowód, nie kontrprzykład, dla zasady
**defense-in-depth**.

---

## 🛡️ Strona obrońcy: jak wykryć tę technikę

Tu domyka się purpura. Skoro rozumiem, jak ta technika omija detekcję statyczną,
wiem też, jak ją **złapać**:

**1. AMSI jest tu kluczowe.** Niezależnie od liczby fragmentów, kod ostatecznie
trafia do silnika skryptowego, gdzie AMSI go widzi w pełnej, zrekonstruowanej
formie. Włączone i poprawnie skonfigurowane AMSI neutralizuje większość wartości
tej techniki.

**2. PowerShell Script Block Logging** (Event ID 4104) — loguje faktycznie
wykonywane bloki, w tym te z dot-source. Łańcuch staje się widoczny w logach.

**3. Detekcja behawioralna łańcucha:**
- Wiele jednoliniowych `.ps1` w jednym katalogu, każdy kończący się
  `. .\lineNNN.ps1` — to **sam w sobie sygnatura** tej techniki.
- Sekwencyjne tworzenie/usuwanie skryptów (tryb `--cleanup`).
- Proces PowerShell dot-source'ujący dziesiątki plików w pętli.

**4. Constrained Language Mode / Execution Policy** — ograniczenie dot-source
i wykonania nieautoryzowanych skryptów u źródła.

> Sygnatura wykrywająca SAMĄ TĘ TECHNIKĘ (łańcuch dot-source jednoliniowców)
> jest trywialna do napisania — co jest kolejnym dowodem, że to nie 0-day, tylko
> luka w *jednej warstwie* detekcji, łatana przez inne warstwy.

---

## Jak działa splitter

`shellsplitter.py` tnie skrypt na bloki, dbając o niełamanie struktur
składniowych:
- śledzi balans nawiasów `{ }` (nie tnie w środku bloku),
- wykrywa here-stringi (`@'...'@`, `@"..."@`) i nie tnie w ich trakcie,
- nie przerywa bloków `try/catch/finally`,
- łączy fragmenty przez `. .\nextfile.ps1` z konfigurowalnym opóźnieniem.

```sh
python shellsplitter.py -i payload.ps1 -o output --chain --runner --delay 200
```

Flagi: `--chain` (łańcuch), `--runner` (generuj runner), `--cleanup` (każdy
fragment kasuje poprzedni), `--delay` (opóźnienie ms), `--comments` (komentarze
wypełniające), `--duckify` (launcher DuckyScript).

---

## Struktura

```
SplitShellChain-AV-Evasion/
├── shellsplitter.py              # splitter (główne narzędzie)
├── invoke-powershelltcp/
│   ├── invoke-powershelltcp.ps1  # oryginał (publiczny, wykrywany)
│   ├── output/                   # pocięty łańcuch (line001..033 + helpery)
│   └── *.png                     # zrzuty eksperymentu
└── keylogger/
    ├── keylogger.ps1             # druga próbka testowa
    └── output/                   # pocięty łańcuch
```

---

## Disclaimer

Materiał do nauki i autoryzowanych testów we własnym labie. Payloady (reverse
shell, keylogger) są publicznie dostępnymi próbkami, użytymi do zademonstrowania
różnicy w detekcji. Nie używać do nieautoryzowanego dostępu — to łamie prawo i
regulaminy platform.

## Autor

Sentio (`salmontts`) — Adrian Jędrocha
