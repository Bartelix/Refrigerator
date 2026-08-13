# Refrigerator — instrukcja setupu

## Wymagania
- Xcode 16+ (SwiftData + iOS 17 target minimum, zalecany iOS 18)
- Telefon podłączony kablem lub przez sieć (Xcode → Window → Devices)

## Kroki

1. Otwórz Xcode → **File → New → Project**
2. Wybierz **iOS → App**
3. Product Name: `Refrigerator`
4. Interface: **SwiftUI**, Language: **Swift**, Storage: zostaw domyślne (nie wybieraj Core Data — użyjemy SwiftData ręcznie)
5. Zapisz projekt

## Podmiana plików

1. Usuń domyślny `ContentView.swift` wygenerowany przez Xcode (ten pusty, z "Hello World")
2. Skopiuj do projektu strukturę folderów z tego paczki:
   - `Models/FoodItem.swift`
   - `Managers/NotificationManager.swift`
   - `Views/ContentView.swift`
   - `Views/FoodListView.swift`
   - `Views/FoodRowView.swift`
   - `Views/AddEditFoodItemView.swift`
3. Podmień plik `RefrigeratorApp.swift` (lub `[NazwaProjektu]App.swift`) zawartością z tego pliku — upewnij się, że nazwa struct `@main` zgadza się z tą wygenerowaną przez Xcode (Xcode może nazwać ją np. `RefrigeratorApp`, sprawdź czy się zgadza)
4. Przeciągnij foldery do Xcode: **prawy klik na projekt w Navigatorze → Add Files to "Refrigerator"** → zaznacz "Copy items if needed" i "Create groups"

## Uruchomienie na telefonie

1. Podłącz iPhone kablem (lub sparuj przez Wi-Fi w Window → Devices and Simulators)
2. W Xcode wybierz swój telefon jako target (obok przycisku Run)
3. **Signing & Capabilities** (klik na nazwę projektu → Target → zakładka Signing): wybierz swój Apple ID jako Team (darmowe konto dev wystarczy)
4. Cmd+R aby zbudować i wgrać na telefon
5. Przy pierwszym uruchomieniu telefon poprosi o zaufanie deweloperowi: **Ustawienia → Ogólne → VPN i zarządzanie urządzeniem → zaufaj swojemu Apple ID**

## Co zawiera aplikacja

- Dwie zakładki: **Lodówka** i **Zamrażarka**
- Każdy produkt: nazwa, kategoria, opcjonalna waga (g), opcjonalna ilość (szt.), data włożenia, notatki
- Tylko w Lodówce: opcjonalny termin ważności (kolorowanie: pomarańczowy ≤3 dni, czerwony po przeterminowaniu)
- Tylko w Zamrażarce: badge "X dni w zamrażarce" wyliczany automatycznie z daty włożenia — szary do 3 miesięcy, pomarańczowy 3-6 miesięcy, czerwony powyżej 6 miesięcy (orientacyjne progi, można łatwo zmienić w `FoodItem.swift` → `freezerFreshness`)
- Sortowanie: po dacie (najnowsze/najstarsze) i alfabetycznie
- Filtrowanie: wyszukiwarka po nazwie + filtr po kategorii
- Podsumowanie na dole listy: liczba pozycji + łączna waga
- Dane zapisywane lokalnie przez SwiftData (SQLite pod spodem), zero internetu
- **Powiadomienia lokalne** (offline, bez serwera):
  - Lodówka: przypomnienie 5 i 3 dni przed terminem ważności
  - Zamrażarka: przypomnienie po 1 miesiącu od włożenia, potem co tydzień
  - Przy pierwszym uruchomieniu aplikacja poprosi o zgodę na powiadomienia — potwierdź w systemowym oknie
  - **Ważne:** iOS pozwala na maks. 64 zaplanowane powiadomienia na aplikację. Dla zamrażarki appka planuje zawsze tylko najbliższe nadchodzące przypomnienie per produkt i odświeża je przy każdym otwarciu aplikacji — więc żeby seria "co tydzień" działała bez przerw, otwieraj appkę choć raz na jakiś czas (np. przy okazji kolejnych zakupów). Dla lodówki oba przypomnienia (5 i 3 dni) planowane są od razu, bo to tylko 2 na produkt.

## Rozbudowa na przyszłość (opcjonalnie)
- Powiadomienia push o zbliżającym się terminie ważności (UNUserNotificationCenter)
- Widget na ekranie głównym pokazujący co się kończy
- Eksport/import CSV do backupu
