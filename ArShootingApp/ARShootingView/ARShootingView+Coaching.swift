import ARKit

extension ARShootingView: ARCoachingOverlayViewDelegate {

    // コーチングオーバーレイビュー追加
    func addCoachingOverlayView() {

        UIApplication.shared.isIdleTimerDisabled = true

        coachingOverlayView.session = arView.session
        coachingOverlayView.delegate = self
        coachingOverlayView.goal = .horizontalPlane
        coachingOverlayView.setActive(true, animated: true)

        arView.addSubview(coachingOverlayView)
    }

    // コーチングオーバーレイビューが完了すると呼ばれます
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {

        UIApplication.shared.isIdleTimerDisabled = false

        coachingOverlayView.activatesAutomatically = false
        coachingOverlayView.setActive(false, animated: false)
        coachingOverlayView.delegate = nil
        coachingOverlayView.removeFromSuperview()

        // 対戦モード
         if gameInfo.gameState == .multiPlayPlacingContent {
             startMultiPlay()
         }
         else if gameInfo.gameState == .multiPlayCPUPlacingContent {
              startMultiPlayCPU()
          }
         else {

        startGame()
         }
    }
}
