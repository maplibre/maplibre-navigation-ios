import UIKit

extension NavigationView {
    func setupConstraints() {
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: topAnchor),
            mapView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapView.bottomAnchor.constraint(equalTo: bottomAnchor),
            mapView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            instructionsBannerContentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            instructionsBannerContentView.bottomAnchor.constraint(equalTo: instructionsBannerView.bottomAnchor),
            instructionsBannerContentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            instructionsBannerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            instructionsBannerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            instructionsBannerView.heightAnchor.constraint(equalToConstant: 96),
            
            informationStackView.topAnchor.constraint(equalTo: instructionsBannerView.bottomAnchor),
            informationStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            informationStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            floatingStackView.topAnchor.constraint(equalTo: informationStackView.bottomAnchor, constant: 10),
            floatingStackView.trailingAnchor.constraint(equalTo: safeTrailingAnchor, constant: -10),
            
            resumeButton.leadingAnchor.constraint(equalTo: safeLeadingAnchor, constant: 10),
            resumeButton.bottomAnchor.constraint(equalTo: bottomBannerView.topAnchor, constant: -10),
            
            bottomBannerContentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBannerContentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBannerContentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBannerContentView.topAnchor.constraint(equalTo: bottomBannerView.topAnchor),
            
            bottomBannerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBannerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBannerView.bottomAnchor.constraint(equalTo: safeBottomAnchor),
            
            wayNameView.centerXAnchor.constraint(equalTo: centerXAnchor),
            wayNameView.bottomAnchor.constraint(equalTo: bottomBannerView.topAnchor, constant: -10)
        ])
        NSLayoutConstraint.activate(bannerShowConstraints)
    }
    
    func constrainEndOfRoute() {
        endOfRouteHideConstraint?.isActive = true
        
        endOfRouteView?.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        endOfRouteView?.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        
        endOfRouteHeightConstraint?.isActive = true
    }
}
