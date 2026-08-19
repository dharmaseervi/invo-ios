//
//  PrintManager.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/15/25.
//


import UIKit

enum PrintManager {

    static func printImage(
        _ image: UIImage,
        jobName: String
    ) {
        let controller = UIPrintInteractionController.shared

        let info = UIPrintInfo(dictionary: nil)
        info.jobName = jobName
        info.outputType = .photo

        controller.printInfo = info
        controller.printingItem = image

        controller.present(animated: true)
    }
}
