import Foundation

@MainActor
protocol HealthCheckable: AnyObject {
    func healthCheck()
}

/// The 1s watchdog the event taps share. Weak subscribers, and no timer while none is registered.
@MainActor
final class HealthTicker {
    private struct WeakSubscriber {
        weak var value: (any HealthCheckable)?
    }

    private var subscribers: [ObjectIdentifier: WeakSubscriber] = [:]
    private var timer: Timer?

    func subscribe(_ subscriber: any HealthCheckable) {
        subscribers[ObjectIdentifier(subscriber)] = WeakSubscriber(value: subscriber)
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Recovery, not latency: tolerance lets the kernel coalesce the idle wakeup.
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func unsubscribe(_ subscriber: any HealthCheckable) {
        subscribers.removeValue(forKey: ObjectIdentifier(subscriber))
        stopIfIdle()
    }

    private func tick() {
        for (key, subscriber) in subscribers {
            guard let value = subscriber.value else {
                subscribers.removeValue(forKey: key)
                continue
            }
            value.healthCheck()
        }
        stopIfIdle()
    }

    private func stopIfIdle() {
        guard subscribers.isEmpty else { return }
        timer?.invalidate()
        timer = nil
    }
}
