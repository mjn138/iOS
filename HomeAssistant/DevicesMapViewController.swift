//
//  DevicesMapViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import MapKit
import SwiftDate

enum MapType: Int {
    case Standard = 0
    case Hybrid
    case Satellite
}

class DeviceAnnotation: MKPointAnnotation {
    var device: DeviceTracker?
}

class ZoneAnnotation: MKPointAnnotation {
    var zone: Zone?
}

class HACircle: MKCircle {
    var type: String = "zone"
}

class DevicesMapViewController: UIViewController, MKMapViewDelegate {

    var devices: [Entity]?
    var zones: [Entity]?
    
    var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Devices & Zones"
        
        self.navigationController?.toolbarHidden = false
        
        let items = ["Standard", "Hybrid", "Satellite"]
        let typeController = UISegmentedControl(items: items)
        typeController.selectedSegmentIndex = 0
        typeController.addTarget(self, action: #selector(DevicesMapViewController.switchMapType(_:)), forControlEvents: .ValueChanged)
        
        let uploadIcon = getIconForIdentifier("mdi:upload", iconWidth: 30, iconHeight: 30, color: colorWithHexString("#44739E", alpha: 1))
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: uploadIcon, style: .Plain, target: self, action: #selector(DevicesMapViewController.sendCurrentLocation(_:)))
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: #selector(DevicesMapViewController.closeMapView(_:)))
        
        // Do any additional setup after loading the view.
        mapView = MKMapView()
        
        mapView.mapType = .Standard
        mapView.frame = view.frame
        mapView.delegate = self
        mapView.showsUserLocation = false
        mapView.showsPointsOfInterest = false
        view.addSubview(mapView)
        
        let locateMeButton = MKUserTrackingBarButtonItem(mapView: mapView)
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: self, action: nil)
        let segmentedControlButtonItem = UIBarButtonItem(customView: typeController)
//        let bookmarksButton = UIBarButtonItem(barButtonSystemItem: .Bookmarks, target: self, action: nil)
        
        self.setToolbarItems([locateMeButton, flexibleSpace, segmentedControlButtonItem, flexibleSpace], animated: true)
        
        for zone in zones! {
            let zone = zone as! Zone
            if let radius = zone.Radius {
                let circle = HACircle.init(centerCoordinate: zone.locationCoordinates(), radius: radius)
                circle.type = "zone"
                mapView.addOverlay(circle)
            }
        }
        
        for device in devices! {
            let device = device as! DeviceTracker
            if device.Latitude == nil || device.Longitude == nil {
                continue
            }
            let dropPin = DeviceAnnotation()
            dropPin.coordinate = device.locationCoordinates()
            dropPin.title = device.FriendlyName
            var subtitlePieces : [String] = []
            if let changedTime = device.LastChanged {
                subtitlePieces.append("Last seen: "+changedTime.toRelativeString(abbreviated: true, maxUnits: 1)!+" ago")
            }
            if let battery = device.Battery {
                subtitlePieces.append("Battery: "+String(battery)+"%")
            }
            dropPin.subtitle = subtitlePieces.joinWithSeparator(" / ")
            dropPin.device = device
            mapView.addAnnotation(dropPin)
            
            if let radius = device.GPSAccuracy {
                let circle = HACircle.init(centerCoordinate: device.locationCoordinates(), radius: radius)
                circle.type = "device"
                mapView.addOverlay(circle)
            }
            
        }
        
        var zoomRect:MKMapRect = MKMapRectNull
        for index in 0..<mapView.annotations.count {
            let annotation = mapView.annotations[index]
            let aPoint:MKMapPoint = MKMapPointForCoordinate(annotation.coordinate)
            let rect:MKMapRect = MKMapRectMake(aPoint.x, aPoint.y, 0.1, 0.1)
            
            zoomRect = MKMapRectUnion(zoomRect, rect)
        }

        let rect = mapView.overlays.reduce(mapView.overlays.first!.boundingMapRect, combine: {MKMapRectUnion($0, $1.boundingMapRect)})
        
        mapView.setVisibleMapRect(MKMapRectUnion(zoomRect, rect), edgePadding: UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0), animated: true)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func switchMapType(sender: UISegmentedControl) {
        let mapType = MapType(rawValue: sender.selectedSegmentIndex)
        switch (mapType!) {
        case .Standard:
            mapView.mapType = MKMapType.Standard
        case .Hybrid:
            mapView.mapType = MKMapType.Hybrid
        case .Satellite:
            mapView.mapType = MKMapType.Satellite
        }
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DeviceAnnotation {
            let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: annotation.device?.ID)
            annotationView.animatesDrop = true
            annotationView.canShowCallout = true
            if let picture = annotation.device?.DownloadedPicture {
                annotationView.leftCalloutAccessoryView = UIImageView(image: picture)
            } else {
                annotationView.leftCalloutAccessoryView = UIImageView(image: annotation.device!.EntityIcon())
            }
//            annotationView.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
            return annotationView
        } else {
            return nil
        }
    }
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if let overlay = overlay as? HACircle {
            let circle = MKCircleRenderer(overlay: overlay)
            if overlay.type == "zone" {
                circle.strokeColor = UIColor.redColor()
                circle.fillColor = UIColor(red: 255, green: 0, blue: 0, alpha: 0.1)
                circle.lineWidth = 1
                circle.lineDashPattern = [2, 5]
            } else if overlay.type == "device" {
                circle.strokeColor = UIColor.blueColor()
                circle.fillColor = UIColor(red: 0, green: 0, blue: 255, alpha: 0.1)
                circle.lineWidth = 1
            }
            return circle
        } else {
            return MKOverlayRenderer(overlay: overlay)
        }
    }
    
    func closeMapView(sender: UIBarButtonItem) {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func sendCurrentLocation(sender: UIBarButtonItem) {
        HomeAssistantAPI.sharedInstance.sendOneshotLocation("One off location update requested").then { success -> Void in
            print("Did succeed?", success)
            let alert = UIAlertController(title: "Location updated", message: "Successfully sent a one shot location to the server", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }.error { error in
            let nserror = error as NSError
            let alert = UIAlertController(title: "Location failed to update", message: "Failed to send current location to server. The error was \(nserror.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
}
