import UIKit

extension NavigationView {
    func setupConstraints() {
        NSLayoutConstraint.activate([
            self.mapView.topAnchor.constraint(equalTo: self.topAnchor),
            self.mapView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.mapView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.mapView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            self.instructionsBannerContentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.instructionsBannerContentView.bottomAnchor.constraint(equalTo: self.instructionsBannerView.bottomAnchor),
            self.instructionsBannerContentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            self.instructionsBannerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.instructionsBannerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.instructionsBannerView.heightAnchor.constraint(equalToConstant: 96),
            
            self.informationStackView.topAnchor.constraint(equalTo: self.instructionsBannerView.bottomAnchor),
            self.informationStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.informationStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            self.floatingStackView.topAnchor.constraint(equalTo: self.informationStackView.bottomAnchor, constant: 10),
            self.floatingStackView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            
            self.resumeButton.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            self.resumeButton.bottomAnchor.constraint(equalTo: self.bottomBannerView.topAnchor, constant: -10),
            
            self.bottomBannerContentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.bottomBannerContentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.bottomBannerContentView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.bottomBannerContentView.topAnchor.constraint(equalTo: self.bottomBannerView.topAnchor),
            
            self.bottomBannerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.bottomBannerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.bottomBannerView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            
            self.wayNameView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.wayNameView.bottomAnchor.constraint(equalTo: self.bottomBannerView.topAnchor, constant: -10)
        ])
        NSLayoutConstraint.activate(self.bannerShowConstraints)
    }

    func constrainEndOfRoute() {
        endOfRouteHideConstraint?.isActive = true

        endOfRouteView?.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        endOfRouteView?.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

        endOfRouteHeightConstraint?.isActive = true
    }
}
