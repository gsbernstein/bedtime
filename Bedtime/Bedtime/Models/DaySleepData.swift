//
//  DaySleepData.swift
//  Bedtime
//
//  Created by Greg on 10/4/25.
//

import Foundation

struct DaySleepData {
    let date: Date
    let nightSleep: [SleepSession]
    let naps: [SleepSession]
    
    var totalNightSleepHours: Double {
        return nightSleep.reduce(0) { $0 + $1.durationInHours }
    }
    
    var totalNapHours: Double {
        return naps.reduce(0) { $0 + $1.durationInHours }
    }
    
    var totalSleepHours: Double {
        return totalNightSleepHours + totalNapHours
    }
    
    init(date: Date, allSessions: [SleepSession]) {
        self.date = date
        
        // Sort sessions by start time
        let sortedSessions = allSessions.sorted { $0.startDate < $1.startDate }
        
        // Group sessions by gaps (> 2 hours between end and start)
        var chunks: [[SleepSession]] = []
        var currentChunk: [SleepSession] = []
        
        for session in sortedSessions {
            if let lastSession = currentChunk.last {
                let gap = session.startDate.timeIntervalSince(lastSession.endDate)
                if gap > 2 * 60 * 60 { // 2 hours gap
                    if !currentChunk.isEmpty {
                        chunks.append(currentChunk)
                        currentChunk = []
                    }
                }
            }
            currentChunk.append(session)
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        // Classify chunks as night sleep or naps
        var nightSleep: [SleepSession] = []
        var naps: [SleepSession] = []
        
        for chunk in chunks {
            guard let firstSession = chunk.first else { continue }
            let startHour = Calendar.current.component(.hour, from: firstSession.startDate)
            
            // Night sleep: starts between 6 PM and 6 AM
            if startHour >= 18 || startHour < 6 {
                nightSleep.append(contentsOf: chunk)
            } else {
                // Naps: starts between 6 AM and 6 PM
                naps.append(contentsOf: chunk)
            }
        }
        
        self.nightSleep = nightSleep
        self.naps = naps
    }
}
