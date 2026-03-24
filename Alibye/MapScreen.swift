import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject var locationService: LocationService

    var body: some View {
        let center = locationService.route.last ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

        Map(initialPosition: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))) {
            UserAnnotation()
            if locationService.route.count > 1 {
                MapPolyline(coordinates: locationService.route)
                    .stroke(.blue, lineWidth: 4)
            }
        }
    }
}
