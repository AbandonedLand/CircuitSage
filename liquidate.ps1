function Make-Offer {
    $offer = Build-SageOffer
    $offer.requestCat('ae1536f56760e471ad85ead45f00d680ff9cca73b8cc3407be778f1c0c606eac',50000)
    $offer.offerXch((52.63 | ConvertTo-XchMojo))
    $offer.createoffer()
    $offer.submit()

}