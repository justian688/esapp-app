//
//  MotionDetector.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/21.
//

import Vision
import CoreMedia
import QuartzCore

actor MotionDetector {
    private var lastProcessingTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 1.0
    
    
    func detectHuman(in sampleBuffer: CMSampleBuffer) async -> Bool {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessingTime >= processingInterval else { return false }
        lastProcessingTime = currentTime
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return false }
        
        return await withCheckedContinuation { continuation in
            let request = VNDetectHumanRectanglesRequest { request, error in
                if let results = request.results as? [VNHumanObservation], !results.isEmpty {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
            
            request.revision = VNDetectHumanRectanglesRequestRevision2
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
