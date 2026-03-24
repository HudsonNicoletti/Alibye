import SwiftUI
import MapKit

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let visitCoordinates: [CLLocationCoordinate2D]
    var refreshToken: UUID
    var movingCoordinate: CLLocationCoordinate2D? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .includingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)

        let existingAnnotations = mapView.annotations.filter {
            !($0 is MKUserLocation)
        }
        mapView.removeAnnotations(existingAnnotations)

        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            mapView.setVisibleMapRect(
                polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 180, left: 40, bottom: 220, right: 40),
                animated: true
            )
        } else if let first = coordinates.first {
            let region = MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        }

        for coordinate in visitCoordinates {
            let pin = MKPointAnnotation()
            pin.coordinate = coordinate
            pin.title = "visit"
            mapView.addAnnotation(pin)
        }

        if let movingCoordinate {
            let movingPin = MKPointAnnotation()
            movingPin.coordinate = movingCoordinate
            movingPin.title = "moving"
            mapView.addAnnotation(movingPin)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.lineWidth = 5
            renderer.strokeColor = .systemBlue
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            if annotation.title == "moving" {
                let identifier = "moving-dot"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                view.annotation = annotation
                view.canShowCallout = false
                view.image = movingDotImage()
                view.centerOffset = CGPoint(x: 0, y: 0)
                return view
            } else {
                let identifier = "visit-pin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

                view.annotation = annotation
                view.markerTintColor = .systemBlue
                view.glyphImage = UIImage(systemName: "mappin.and.ellipse")
                view.titleVisibility = .hidden
                view.subtitleVisibility = .hidden
                return view
            }
        }

        private func movingDotImage() -> UIImage? {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
            return renderer.image { context in
                let rect = CGRect(x: 0, y: 0, width: 24, height: 24)

                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: rect)

                UIColor.systemBlue.setFill()
                context.cgContext.fillEllipse(in: rect.insetBy(dx: 4, dy: 4))
            }
        }
    }
}
