import SwiftUI
import MapKit

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let visitCoordinates: [CLLocationCoordinate2D]
    var refreshToken: UUID
    var followUser: Bool = false
    var movingCoordinate: CLLocationCoordinate2D? = nil
    var heatmapCoordinates: [CLLocationCoordinate2D] = []

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
        if followUser {
            mapView.setUserTrackingMode(.follow, animated: false)
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)

        let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existingAnnotations)

        if !heatmapCoordinates.isEmpty {
            let cells = aggregatedHeatmapCells(from: heatmapCoordinates)
            for cell in cells {
                let circle = WeightedCircle(center: cell.coordinate, radius: cell.radiusMeters, weight: cell.weight)
                mapView.addOverlay(circle)
            }
        }

        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)

            if !followUser {
                mapView.setVisibleMapRect(
                    polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 160, left: 40, bottom: 220, right: 40),
                    animated: false
                )
            }
        } else if let first = coordinates.first, !followUser {
            let region = MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: false)
        }

        if followUser {
            mapView.setUserTrackingMode(.follow, animated: false)
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

            let region = MKCoordinateRegion(
                center: movingCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: false)
        }
    }

    private func aggregatedHeatmapCells(from coordinates: [CLLocationCoordinate2D]) -> [HeatCell] {
        var buckets: [String: Int] = [:]
        var centers: [String: CLLocationCoordinate2D] = [:]

        for coordinate in coordinates {
            let lat = (coordinate.latitude * 500).rounded() / 500
            let lon = (coordinate.longitude * 500).rounded() / 500
            let key = "\(lat),\(lon)"
            buckets[key, default: 0] += 1
            centers[key] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        return buckets.compactMap { key, weight in
            guard let coordinate = centers[key] else { return nil }
            let radius = min(120.0, 30.0 + Double(weight * 8))
            return HeatCell(coordinate: coordinate, weight: weight, radiusMeters: radius)
        }
    }

    struct HeatCell {
        let coordinate: CLLocationCoordinate2D
        let weight: Int
        let radiusMeters: CLLocationDistance
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let weighted = overlay as? WeightedCircle {
                let renderer = MKCircleRenderer(circle: weighted)
                let alpha = min(0.55, 0.12 + CGFloat(weighted.weight) * 0.03)
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(alpha)
                renderer.strokeColor = UIColor.systemRed.withAlphaComponent(min(0.7, alpha + 0.1))
                renderer.lineWidth = 1
                return renderer
            }

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
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 26, height: 26))
            return renderer.image { _ in
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 26, height: 26)).fill()

                UIColor.systemBlue.setFill()
                UIBezierPath(ovalIn: CGRect(x: 4, y: 4, width: 18, height: 18)).fill()
            }
        }
    }
}

final class WeightedCircle: MKCircle {
    var weight: Int = 1

    convenience init(center: CLLocationCoordinate2D, radius: CLLocationDistance, weight: Int) {
        self.init(center: center, radius: radius)
        self.weight = weight
    }
}
