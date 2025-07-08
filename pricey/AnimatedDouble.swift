import Foundation

class AnimatedDouble {
    private var _value: Double = 0.0
    private var targetValue: Double = 0.0
    private var animationTimer: Timer?
    private let animationDuration: TimeInterval = 1.0
    private var animationStartTime: Date?
    private var animationStartValue: Double = 0.0
    private var updateCallback: ((Double) -> Void)?
    
    var value: Double {
        get { _value }
        set { animateToValue(newValue) }
    }
    
    init(initialValue: Double = 0.0, updateCallback: @escaping (Double) -> Void) {
        self._value = initialValue
        self.targetValue = initialValue
        self.updateCallback = updateCallback
    }
    
    private func animateToValue(_ newValue: Double) {
        animationTimer?.invalidate()
        
        targetValue = newValue
        animationStartTime = Date()
        animationStartValue = _value
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }
    
    private func updateAnimation() {
        guard let startTime = animationStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(elapsed / animationDuration, 1.0)
        
        let easedProgress = easeInOut(progress)
        _value = animationStartValue + (targetValue - animationStartValue) * easedProgress
        
        updateCallback?(_value)
        
        if progress >= 1.0 {
            animationTimer?.invalidate()
            animationTimer = nil
            _value = targetValue
            updateCallback?(_value)
        }
    }
    
    private func easeInOut(_ t: Double) -> Double {
        return t * t * (3.0 - 2.0 * t)
    }
    
    func setValueImmediately(_ value: Double) {
        animationTimer?.invalidate()
        animationTimer = nil
        _value = value
        targetValue = value
        updateCallback?(value)
    }
}
