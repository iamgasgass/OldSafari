// PULIZIA in OldSafari/Views/SafariControls.swift
// Elimina interamente questa struct (codice morto, non referenziato da
// nessuna vista): produce la griglia di separatori "fantasma" che si vede
// nelle vecchie build di Downloads/Cronologia quando viene agganciata come
// overlay/background di una lista. Rimuoverla previene che possa essere
// invocata per errore in futuro.
//
// struct OldOSTableFiller: View {
//     let theme: OldOSSafariTheme
//     var rowHeight: CGFloat = 44
//     var separator: CGFloat = 0.95
//
//     var body: some View {
//         GeometryReader { geometry in
//             let rows = max(Int(ceil(geometry.size.height / rowHeight)) + 1, 1)
//             VStack(spacing: 0) {
//                 ForEach(0..<rows, id: \.self) { _ in
//                     VStack(spacing: 0) {
//                         Rectangle().fill(theme.listBackground)
//                             .frame(height: rowHeight - separator)
//                         Rectangle().fill(theme.listSeparator)
//                             .frame(height: separator)
//                     }
//                 }
//             }
//             .frame(height: geometry.size.height, alignment: .top)
//             .clipped()
//         }
//         .allowsHitTesting(false)
//     }
// }
//
// Cancella semplicemente queste righe da SafariControls.swift. Nessun altro
// file la referenzia (verificato su tutti i file del progetto forniti),
// quindi la rimozione è sicura e non rompe nulla.
