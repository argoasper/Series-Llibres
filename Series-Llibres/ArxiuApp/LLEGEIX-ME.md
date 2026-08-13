# El Meu Arxiu — app nativa iOS / iPadOS

Traducció a SwiftUI de `Per Fer APP — Sèries, Pel·lícules i Llibres.html`,
amb els set canvis demanats ja aplicats.

## Obrir-lo

1. Doble clic a `ArxiuApp.xcodeproj`.
2. Selecciona el target **ArxiuApp** → pestanya *Signing & Capabilities* → tria el teu equip.
   És l'únic camp que has d'omplir; l'identificador és `com.francescgallego.ArxiuApp`.
3. Tria un simulador (o el teu iPhone) i prem ▶.

Requereix **Xcode 16** i **iOS 17** o superior. El projecte usa carpetes sincronitzades,
o sigui que si hi afegeixes un fitxer `.swift` dins de `ArxiuApp/` Xcode el recull tot sol.

## Les teves dades

`ArxiuApp/Resources/SeedData.json` conté les **355 fitxes i 132 llibres**
exportats de l'HTML. S'importen soles el primer cop que s'obre l'app i
mai més (`SeedLoader`). A partir d'aquí tot viu a SwiftData, al dispositiu.

De les 30 sèries que tenien la temporada al títol —`Mad Men (T6)`, `Ciclos (t5)`…—
se n'extreu el número al camp `season` durant la importació, sense tocar el títol.

## Els set canvis

| # | Què has demanat | On és |
|---|---|---|
| 1 | Temporada a les sèries | Camp `season`. Insígnia blava «T3» a la fila, camp propi al formulari (només si el tipus és sèrie) i línia al detall. |
| 2 | La icona | `Assets.xcassets/AppIcon.appiconset`, generada de la teva imatge: retallada, fons ampliat i sense les cantonades arrodonides originals perquè iOS hi apliqui la seva màscara. |
| 3 | Imatge d'entrada | `SplashView`, amb l'art de la icona sobre un degradat. Entra amb un rebot suau i es fon cap a la pantalla d'inici. |
| 4 | Botó de desfer | `ChangeHistory` guarda els últims 40 canvis d'estat. Hi ha una fletxa ↺ a la barra d'eines de totes les pantalles i una barra flotant «Desfés» que surt 4 segons després de cada canvi. Es restaura l'estat **i** la data d'acabament. |
| 5 | Ajustos que no servia | Eliminat. La clau d'OMDb es demana en una alerta, un sol cop, la primera vegada que prems «Cerca info» en una sèrie o pel·lícula. |
| 6 | Botons tipus la imatge | `Tile` / `TileButton`. Els grans són la pantalla d'entrada (Tot, Sèries, Pel·lícules, Llibres, En curs, Pendent) i els petits el submenú de filtres de dins de cada llista. Mateix llenguatge visual, mida reduïda. |
| 7 | Mes i any en format AAAA/MM | Camp `completedAt`. S'omple sol amb el mes actual en marcar alguna cosa com a vista o llegida, s'esborra si la desmarques, i el pots editar a mà al formulari. Es mostra sota el títol a la llista. |

## Estructura

```
ArxiuApp/
├── Models/
│   ├── Enums.swift          MediaKind (serie/peli/llibre), ItemStatus, SortOrder
│   ├── LibraryItem.swift    el model SwiftData
│   └── Backup.swift         JSON de l'HTML ↔ LibraryItem
├── Store/
│   ├── SeedLoader.swift     importació inicial
│   ├── LibraryActions.swift canvis d'estat, esborrat, desfer
│   └── ChangeHistory.swift  la pila de desfer
├── Services/
│   └── MetadataService.swift  OMDb + Google Books
├── Views/                   Tile, Home, Llista, Fila, Detall, Formulari, Splash, UndoBar
└── Support/                 Theme (paleta del CSS), Haptics, Formatters
```

## Notes

- Els dos vocabularis d'estat de l'HTML (`veient`/`vist` i `pendent`/`llegit`)
  s'han unificat en `pendent → en curs → fet`, i cada tipus en mostra el nom
  que li toca: una sèrie diu «Vist», un llibre diu «Llegit».
- El cercle de la fila avança d'estat a cada toc, com a l'HTML. També hi ha
  swipe a l'esquerra per marcar i a la dreta per eliminar o posar en curs.
- `Backup.swift` ja sap serialitzar cap al mateix format JSON que exportava
  l'HTML. Falta només enganxar-hi un `ShareLink` i un `fileImporter` si vols
  recuperar els botons d'exportar i importar.
