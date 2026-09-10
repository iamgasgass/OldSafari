// SOSTITUISCI in OldSafari/Views/SafariToolbar.swift, nel blocco `.browsing`
// di `body`, questa porzione:
//
//     OldOSToolBarButton(
//         image: "NavAction",
//         action: onShare,
//         onLongPress: onDownloadsTap
//     )
//     .overlay(alignment: .topTrailing) {
//         if downloadCount > 0 {
//             DownloadBadge(count: downloadCount)
//                 .offset(x: -8, y: 11)
//                 .allowsHitTesting(false)
//         }
//     }
//
// con questa versione. Cambia solo l'offset del badge, per non coprire più
// il glifo dell'icona NavAction (la "sharesheet") quando la notifica di
// download è visibile.

OldOSToolBarButton(
    image: "NavAction",
    action: onShare,
    onLongPress: onDownloadsTap
)
.overlay(alignment: .topTrailing) {
    if downloadCount > 0 {
        DownloadBadge(count: downloadCount)
            // FIX: y:11 sovrapponeva parzialmente il glifo dell'icona
            // "condividi/azioni" sottostante. Spostando il badge un po'
            // più in basso e verso l'esterno resta ancorato all'angolo
            // del pulsante senza coprire l'icona.
            .offset(x: -6, y: 15)
            .allowsHitTesting(false)
    }
}

// Nota: se dopo questa modifica il badge ti sembra ancora leggermente alto
// o basso sul tuo dispositivo, regola solo il secondo valore (attualmente
// 15) di 1-2pt alla volta: dipende dalle dimensioni esatte dell'asset
// "NavAction" che non ho potuto misurare pixel per pixel da qui.
