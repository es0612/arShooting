import SwiftUI
import ARKit
import RealityKit
import Combine
import MultipeerConnectivity

struct SendType {
    static let damage: String = "Damage"
}

struct DamageNum {
    static let multiPlay: Int = 1
}

struct EntityName {
    static let bulletAnchor = "BulletAnchor" + UIDevice.current.name
    static let bullet = "Bullet"

    // 弾丸
    static let selfBullet = "SelfBullet"
    static let enemyBullet = "EnemyBullet"

    // カメラの当たり判定
    static let cameraBox = "CameraBox"

    // 対戦モードの敵当たり判定
    static let multiHitBox: String = "MultiHitBox"
}

struct ModelInfo {
    var name: String = ""
    var life: Int = 0
}

struct StageModel {

    // ステージ1
    var rocket1 = ModelInfo(name: "Rocket1", life: 10)
    var rocket2 = ModelInfo(name: "rocket2", life: 10)
    var drummer2 = ModelInfo(name: "drummer2", life: 10)

    func stage1() -> Array<ModelInfo> {
        return [rocket1]
    }
    func stage2() -> Array<ModelInfo> {
        return [rocket2, drummer2]
    }
}

struct RulerInfo {

    static let pointNum = 2
}

class ARShootingView: UIView, ARSessionDelegate {

    // ARView
    let arView = ARView(frame: UIScreen.main.bounds)

    // コーチングオーバーレイビュー
    var coachingOverlayView = ARCoachingOverlayView(frame: UIScreen.main.bounds)

    var gameAnchor = try! GameStages.loadStage1()

    // ゲーム情報
    var gameInfo: GameInfo

    // ゲーム情報を受け取るタスク
    var gameInfoTask: AnyCancellable?

    var stageModel = StageModel()

    var enemyBulletTimer: Timer?

    var collisionEventStreams = [AnyCancellable]()

    var startFlg: Bool = false

    // マルチピア接続
    static let multiServiceType = "multiAR"

    let multiPeerID = MCPeerID(displayName: UIDevice.current.name)
    var multiEnemyPeerIDName = ""
    var multiSession: MCSession!
    var multiAdvertiser: MCNearbyServiceAdvertiser!
    var multiBrowser: MCNearbyServiceBrowser!

    // シミュレーター
        var arSimulator: ARSimulator!
        var simulatorAnchorEntity: AnchorEntity!

    // 初期化
    init(frame frameRect: CGRect, gameInfo: GameInfo) {

        // ゲーム情報の受け取り
        self.gameInfo = gameInfo

        // 親クラスの初期化
        super.init(frame: frameRect)


        arView.session.delegate = self

        // ARViewの追加
        addSubview(arView)

        // ゲーム情報の受け取りタスク
        self.gameInfoTask = gameInfo.$gameState.receive(on: DispatchQueue.main).sink { (value) in
            if value == .menu {

                if self.startFlg == true {

                    self.gameInfo.selfLife = 10
                    self.stageModel.rocket1.life = 10
                    self.stageModel.rocket2.life = 10
                    self.stageModel.drummer2.life = 10

                    self.gameAnchor.removeFromParent()

                    self.gameAnchor = try! GameStages.loadStage1()

                    self.arView.scene.addAnchor(self.gameAnchor)
                }
            }
            else if value == .placingContent {
                if self.startFlg == false {
                    self.setupConfiguration()

                    self.addCoachingOverlayView()
                } else {
                    gameInfo.gameState = .stage1
                }

            }
            else if value == .multiPlayPlacingContent {

                self.gameInfo.selfLife = 10
                self.gameInfo.enemyLife = 10

                // コーチングオーバーレイビュー初期化
                self.coachingOverlayView = ARCoachingOverlayView(frame: UIScreen.main.bounds)

                // マルチビア接続初期化
                self.setupMultiPlay()

                self.setupConfiguration()

                self.addCoachingOverlayView()
            }

            else if value == .multiPlayCPUPlacingContent {

                            self.gameInfo.selfLife = 10
                            self.gameInfo.enemyLife = 10

                            // コーチングオーバーレイビュー初期化
                            self.coachingOverlayView = ARCoachingOverlayView(frame: UIScreen.main.bounds)

                            // マルチビア接続初期化
                            self.setupMultiPlay()

                            self.setupARSimulator()

                            self.setupConfiguration()

                            self.addCoachingOverlayView()
                        }

            else if value == .rulerMode {

                  self.setupGestureRecognizers()

                  self.setupConfiguration()
              }
              else if value == .rulerModeEnd {

                  self.arViewReset()

                  // 平面検出の停止
                  self.arView.session.run(ARWorldTrackingConfiguration())

                  self.gameInfo.gameState = .menu
              }
        }
    }

    @objc required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //MARK:- Configuration

    // コンフィグ設定
    func setupConfiguration() {

        // 床の平面を探す
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]

//        if gameInfo.gameState == .multiPlayPlacingContent {
        if  gameInfo.gameState == .multiPlayPlacingContent ||
                   gameInfo.gameState == .multiPlayCPUPlacingContent {
            config.isCollaborationEnabled = true
        }

        arView.session.run(config, options: [])
    }

    //MARK:- Game

    // ゲーム開始
    func startGame() {

        // ゲームアンカー追加
        arView.scene.addAnchor(gameAnchor)

        setupGestureRecognizers()

        // ステージ1に移行
        gameInfo.gameState = .stage1

        // 平面検出の停止
        arView.session.run(ARWorldTrackingConfiguration())

        startFlg = true

        // 3秒に1回敵の弾丸が発射するタイマー
        enemyBulletTimer = Timer.scheduledTimer(timeInterval: 3,
                                                target: self,
                                                selector: #selector(stageBulletShot),
                                                userInfo: nil,
                                                repeats: true)

        // カメラの当たり判定
        let camera = CameraBox(entityName: EntityName.cameraBox)
        let cameraAnchor = AnchorEntity(.camera)
        cameraAnchor.addChild(camera.hitBox)
        arView.scene.addAnchor(cameraAnchor)

        // カメラの10cm後ろに配置します
        camera.hitBox!.transform.translation = [0, 0, 0.1]

        // 衝突イベント
        arView.scene.subscribe(to: CollisionEvents.Began.self) { event in

            // 敵からのダメージ判定
            if  event.entityA.name == EntityName.enemyBullet &&
                    event.entityB.name == EntityName.cameraBox {

                self.gameInfo.selfLife -= 1
            }

            // ステージ１
            if self.gameInfo.gameState == .stage1 {

                self.stage1Damage(entityAName: event.entityA.name, entityBName: event.entityB.name)
            }

            // ステージ2
            else if self.gameInfo.gameState == .stage2 {

                self.stage2Damage(entityA: event.entityA, entityB: event.entityB)
            }

        }.store(in: &collisionEventStreams)
    }

    func stage1Damage(entityAName: String, entityBName: String) {

        // 敵へのダメージ判定
        if  entityAName == EntityName.selfBullet &&
                entityBName == stageModel.rocket1.name {

            // ステージ2へ移行
            if  stageModel.rocket1.life == 0 &&
                    gameInfo.selfLife > 0 {

                gameInfo.gameState = .stage2

                // ステージ変更の通知
                gameAnchor.notifications.changeStage2.post()
            }
            // ダメージ判定
            else {

                stageModel.rocket1.life -= 1

                // サウンド再生と表示アクションの通知
                gameAnchor.notifications.hitRocket1.post()
            }

        }
    }

    func stage2Damage(entityA: Entity, entityB: Entity) {

        // ゲーム終了
        if  stageModel.rocket2.life <= 0 &&
                stageModel.drummer2.life <= 0 &&
                gameInfo.selfLife > 0 {

            gameInfo.gameState = .endGame
        }
        else {

            // ロケットへのダメージ判定
            if  entityA.name == EntityName.selfBullet &&
                    entityB.name == stageModel.rocket2.name {

                // ダメージ判定
                stageModel.rocket2.life -= 1

                // ヒット時のアクション
                hitAction(entity: entityB)
                print("rocket")
            }

            // ドラマーへのダメージ判定
            else if  entityA.name == EntityName.selfBullet &&
                        entityB.name == stageModel.drummer2.name {

                // ダメージ判定
                stageModel.drummer2.life -= 1

                // ヒット時のアクション
                hitAction(entity: entityB)
                print("drummer")
            }

        }
    }

    func hitAction(entity: Entity) {

        // サウンド再生
        let hitSound = try! AudioFileResource.load(named: "HitSound.wav")
        entity.playAudio(hitSound)
    }
    // 敵の弾丸が定期的に発射されます
    @objc func stageBulletShot() {

        var stageInfo: Array<ModelInfo> = []

        // ステージ1のモデル情報を取得
        if gameInfo.gameState == .stage1 {
            stageInfo = stageModel.stage1()
        }

        // ステージ2の情報を取得
        else if gameInfo.gameState == .stage2 {
            stageInfo = stageModel.stage2()
        }

        // 3Dコンテンツから弾丸発射
        for model: ModelInfo in stageInfo {

            enemyBulletShot(name: model.name)
        }
    }

    func enemyBulletShot(name: String) {

        // ロケットのEntityを取得
        let entity = gameAnchor.findEntity(named: name)

        guard let rocketEntity = entity else {
            return
        }

        // カメラの位置を取得
        let cameraPos = gameAnchor.convert(transform: arView.cameraTransform, from: nil)

        // 弾丸を生成
        let enemy = BulletStar(startPosition: rocketEntity.position, entityName: EntityName.enemyBullet)

        // 弾丸を追加
        gameAnchor.addChild(enemy.bullet)

        // ロケットの位置からカメラの位置まで移動させます
        let animeMove = enemy.bullet.move(to: cameraPos,
                                          relativeTo: gameAnchor,
                                          duration: 2,
                                          timingFunction: AnimationTimingFunction.linear)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            animeMove.entity?.removeFromParent()
        }
    }

    //MARK:- MultiPlay

    // 対戦モード開始
    func startMultiPlay() {
        gameInfo.gameState = .multiPlayMode

        // 平面検出の停止とコラボレーションデータ生成開始
        let config = ARWorldTrackingConfiguration()
        config.isCollaborationEnabled = true
        arView.session.run(config, options: [])

        startFlg = false

        // タップジェスチャー
        setupGestureRecognizers()

        // 衝突イベント
        arView.scene.subscribe(to: CollisionEvents.Began.self) { event in

            // 敵へのダメージ判定
            if  event.entityA.name == EntityName.selfBullet &&
                    event.entityB.name == EntityName.multiHitBox {

                for peer in self.multiSession.connectedPeers {

                    // 敵接続先の場合
                    if peer.displayName == self.multiEnemyPeerIDName {

                        // ダメージ送信
                        self.sendCreateData(peers: [peer], sendType: SendType.damage)

                        // ダメージ表示更新
                        self.gameInfo.enemyLife -= DamageNum.multiPlay

                        if self.gameInfo.enemyLife == 0 {

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {

                                self.gameInfo.gameState = .multiPlayWin

                                self.stopMultiPlay()
                            }
                        }

                        break
                    }
                }
            }

        }.store(in: &collisionEventStreams)
    }

    // マルチビア接続
    func setupMultiPlay() {

        // データの送受信を行うクラス
        multiSession = MCSession(peer: multiPeerID, securityIdentity: nil, encryptionPreference: .required)
        multiSession.delegate = self

        // 近くのpeerに自身を告知します
        multiAdvertiser = MCNearbyServiceAdvertiser(peer: multiPeerID, discoveryInfo: nil, serviceType: ARShootingView.multiServiceType)
        multiAdvertiser.delegate = self
        multiAdvertiser.startAdvertisingPeer()

        // 近くのpeerを招待します
        multiBrowser = MCNearbyServiceBrowser(peer: multiPeerID, serviceType: ARShootingView.multiServiceType)
        multiBrowser.delegate = self
        multiBrowser.startBrowsingForPeers()
    }

    // 対戦モード終了
    func stopMultiPlay() {

        // P2P通信停止
        multiAdvertiser.stopAdvertisingPeer()
        multiBrowser.stopBrowsingForPeers()
        multiSession.disconnect()

        // ARView初期化
        arViewReset()

        // 衝突イベント停止
        collisionEventStreams = [AnyCancellable]()
    }

    // ARViewのAnchorとEntity削除
    func arViewReset() {

        for anchor in arView.scene.anchors {

            for entity in anchor.children {
                entity.removeFromParent()
            }

            anchor.removeFromParent()
        }
    }

    // 敵アンカー削除
    func removeAnchor() {

        guard let frame = arView.session.currentFrame else { return }

        for anchor in frame.anchors {

            if let participantAnchor = anchor as? ARParticipantAnchor {

                arView.session.remove(anchor: participantAnchor)
            }
        }
    }

    // ダメージ判定を送信
    func sendCreateData(peers: [MCPeerID], sendType: String) {

        var command = ""

        if sendType == SendType.damage {
            command = SendType.damage + String(DamageNum.multiPlay)
        }

        if let commandData = command.data(using: .utf8) {
            sendData(commandData, reliably: true, peers: peers)
        }
    }

    // データ送信
    func sendData(_ data: Data, reliably: Bool, peers: [MCPeerID]) {

        guard !peers.isEmpty else { return }

        do {
            try multiSession.send(data, toPeers: peers, with: reliably ? .reliable : .unreliable)
        } catch {
            print("Error sendData \(peers): \(error.localizedDescription)")
        }
    }

    // データ受信
    func recvData(_ data: Data, from peer: MCPeerID) {
        // コラボレーションデータの場合
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data)
        {
            // コラボレーションデータを現在の環境に更新
            arView.session.update(with: collaborationData)
        }
        // ダメージ判定の場合
        else if let commandString = String(data: data, encoding: .utf8), commandString.hasPrefix(SendType.damage) {

            // 文字列前半部分(Damage)を削除して、ダメージ数を取得
            let damageNum = String(commandString[commandString.index(commandString.startIndex, offsetBy: SendType.damage.count)...])

            // メインスレッドで更新
            DispatchQueue.main.async {

                self.gameInfo.selfLife -= Int(damageNum)!

                // ゲーム終了
                if self.gameInfo.selfLife == 0 {

                    self.gameInfo.gameState = .multiPlayLose

                    self.stopMultiPlay()
                }
            }
        }
    }

    // 接続判定
    func peerDiscovered(_ peer :MCPeerID) -> Bool {

        // 1台だけ接続を許可
        if multiSession.connectedPeers.count >= 2 {
            return false
        }
        else {
            return true
        }
    }

    // 接続
    func peerConnected(_ peer :MCPeerID) {

        if peer.displayName != multiPeerID.displayName {
            multiEnemyPeerIDName = peer.displayName
        }
    }

    // 切断
    func peerDisconnected(_ peer :MCPeerID) {

        removeAnchor()

        multiEnemyPeerIDName = ""
    }

    //MARK:- ARSimulator

        func setupARSimulator() {

            arSimulator = ARSimulator()

            // P2P通信開始
            arSimulator.setupMultiPlay()
        }

        func startMultiPlayCPU() {

            gameInfo.gameState = .multiPlayCPUMode

            // 平面検出の停止とコラボレーションデータ生成開始
            let config = ARWorldTrackingConfiguration()
            config.isCollaborationEnabled = true
            arView.session.run(config, options: [])

            startFlg = false

            // タップジェスチャー
            setupGestureRecognizers()

            // 衝突イベント
            arView.scene.subscribe(to: CollisionEvents.Began.self) { event in

                // 敵へのダメージ判定
                if  event.entityA.name == EntityName.selfBullet &&
                    event.entityB.name == EntityName.multiHitBox {

                    for peer in self.multiSession.connectedPeers {

                        // 敵接続先の場合
                        if peer.displayName == self.multiEnemyPeerIDName {

                            // ダメージ送信
                            self.sendCreateData(peers: [peer], sendType: SendType.damage)

                            // ダメージ表示更新
                            self.gameInfo.enemyLife -= DamageNum.multiPlay

                            if self.gameInfo.enemyLife == 0 {

                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {

                                    self.gameInfo.gameState = .multiPlayWin

                                    self.stopMultiPlay()

                                    self.arSimulator.stopMultiPlay()

                                    self.enemyBulletTimer?.invalidate()

                                    self.arView.session.run(ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
                                }
                            }

                            break
                        }
                    }
                }
                // 敵からのダメージ判定
                else if event.entityA.name == EntityName.enemyBullet &&
                        event.entityB.name == EntityName.cameraBox {

                    self.gameInfo.selfLife -= 1
                }

            }.store(in: &collisionEventStreams)

            // ARシミュレーターの当たり判定
            simulatorHitBox()

            // カメラの当たり判定
            cameraHitBox()
        }

        func simulatorHitBox() {

            // アンカー生成
            simulatorAnchorEntity = AnchorEntity(plane: .horizontal, minimumBounds: [0.1, 0.1])

            // 当たり判定(緑球体)の生成
            let meth = MeshResource.generateSphere(radius: 0.03)
            let color = UIColor.green

            let material = SimpleMaterial(color: color, isMetallic: false)
            let coloredSphere = ModelEntity(mesh: meth, materials: [material])

            coloredSphere.components[CollisionComponent] = CollisionComponent(
                shapes: [ShapeResource.generateBox(size: [0.1,0.1,0.1])]
            )
            coloredSphere.name = EntityName.multiHitBox
            coloredSphere.position = SIMD3<Float>(0, 0.5, 0)
            simulatorAnchorEntity.addChild(coloredSphere)

            arView.scene.addAnchor(simulatorAnchorEntity)

            // 1.5秒に1回敵の弾丸が発射するタイマー
            enemyBulletTimer = Timer.scheduledTimer(timeInterval: 1.5,
                                                    target: self,
                                                    selector: #selector(simulatorBulletShot),
                                                    userInfo: nil,
                                                    repeats: true)
        }

        func cameraHitBox() {

            // カメラの当たり判定
            let camera = CameraBox(entityName: EntityName.cameraBox)
            let cameraAnchor = AnchorEntity(.camera)
            cameraAnchor.addChild(camera.hitBox)
            arView.scene.addAnchor(cameraAnchor)

            // カメラの10cm後ろに配置します
            camera.hitBox!.transform.translation = [0, 0, 0.1]
        }

        @objc func simulatorBulletShot() {

            guard let anchorEntity = simulatorAnchorEntity else { return }

            var coloredSphere: ModelEntity?

            for entity in simulatorAnchorEntity.children {

                if entity.name == EntityName.multiHitBox {

                    coloredSphere = entity as? ModelEntity
                    break
                }
            }

            guard let hitBox = coloredSphere else { return }

            // カメラの位置を取得
            let cameraPos = anchorEntity.convert(transform: arView.cameraTransform, from: nil)

            // 弾丸を生成
            let enemy = BulletStar(startPosition: hitBox.position, entityName: EntityName.enemyBullet)

            // 弾丸を追加
            simulatorAnchorEntity.addChild(enemy.bullet)

            // ロケットの位置からカメラの位置まで移動させます
            let animeMove = enemy.bullet.move(to: cameraPos,
                                              relativeTo: simulatorAnchorEntity,
                                              duration: 2,
                                              timingFunction: AnimationTimingFunction.linear)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                animeMove.entity?.removeFromParent()
            }

            // シミュレーターのランダム移動
            let xRandom = Float.random(in: -0.2 ... 0.2)
            let yRandom = Float.random(in: -0.2 ... 0.2)
            let zRandom = Float.random(in: -0.2 ... 0.2)

            let movePos = float4x4.init(translation: SIMD3<Float>(hitBox.position.x+xRandom,
                                                                  hitBox.position.y+yRandom,
                                                                  hitBox.position.z+zRandom))

            hitBox.move(to: movePos,
                        relativeTo: anchorEntity,
                        duration: 0.1,
                        timingFunction: AnimationTimingFunction.linear)
        }
    //MARK:- GestureRecognizers

    // ジェスチャー設定
    func setupGestureRecognizers() {
        for recognizer in gestureRecognizers ?? [] {
            removeGestureRecognizer(recognizer)
        }

        // タップして撃つ
//        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(addBulletAnchor(recognizer:)))

        let tapRecognizer: UITapGestureRecognizer!

              // タップして撃つ
              if gameInfo.gameState == .rulerMode {
                  tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(addRulerModel(recognizer:)))
              }
              else {
                  tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(addBulletAnchor(recognizer:)))
              }

        tapRecognizer.numberOfTouchesRequired = 1

        // シーンにジェスチャー追加
        addGestureRecognizer(tapRecognizer)
    }

    // 弾丸のARAnchor追加
    @objc func addBulletAnchor(recognizer: UITapGestureRecognizer){

        // sessionにARAnchorを追加する (ARAnchorはARKitのクラス)
        let bulletAnchor = ARAnchor(name: EntityName.bulletAnchor, transform: arView.cameraTransform.matrix)
        arView.session.add(anchor: bulletAnchor)

    }

    // 弾丸を発射します
    func bulletShot(named entityName: String, for anchor: ARAnchor) {

        // Bulletを取得する
        let bulletEntity = try! ModelEntity.load(named: entityName)

        // ARAnchorをAnchorEntityに変換します
        let anchorEntity = AnchorEntity(anchor: anchor)

        anchorEntity.addChild(bulletEntity)
        arView.scene.addAnchor(anchorEntity)

        // 弾丸が0.4秒で端に到達するので、プラス0.1秒後に消します
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.arView.scene.removeAnchor(anchorEntity)
        }

    }

    // 弾丸を発射します(ソースコードバージョン)
    func bulletShotCode(named entityName: String, for anchor: ARAnchor) {

        // ARAnchorをAnchorEntityに変換します
        let anchorEntity = AnchorEntity(anchor: anchor)

        // 自分自身の弾丸を生成
        //        let bulletEntity = BulletStar(startPosition: anchorEntity.position, entityName: EntityName.selfBullet)
        let bulletEntity = BulletStar(startPosition: anchorEntity.position, entityName: entityName)

        // アンカーに弾丸を追加
        anchorEntity.addChild(bulletEntity.bullet)

        // シーンにアンカーを追加
        arView.scene.addAnchor(anchorEntity)

        // カメラ座標の3m前
        let infrontOfCamera = SIMD3<Float>(x: 0, y: 0, z: -3)

        // カメラ座標 -> アンカー座標
        let bulletPos = anchorEntity.convert(position: infrontOfCamera, to: gameAnchor)

        // 3D座標(xyz)を4×4行列に変換
        let movePos = float4x4.init(translation: bulletPos)

        // 弾丸を移動
        let animeMove = bulletEntity.bullet.move(to: movePos,
                                                 relativeTo: gameAnchor,
                                                 duration: 0.4,
                                                 timingFunction: AnimationTimingFunction.linear)

        // 発射時にサウンド再生
        let hitSound = try! AudioFileResource.load(named: "ShootSound.wav")
        bulletEntity.bullet.playAudio(hitSound)

        // 弾丸が0.4秒で端に到達するので、プラス0.1秒後に消します
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animeMove.entity?.removeFromParent()
            self.arView.scene.removeAnchor(anchorEntity)
        }

    }

    @objc func addRulerModel(recognizer: UITapGestureRecognizer) {

            if arView.scene.anchors.count >= RulerInfo.pointNum {

                arView.scene.anchors[0].removeFromParent()
            }

            let pos = recognizer.location(in: arView)

            // 検出した平面
            let planeHitTestResults = arView.hitTest(pos, types: .existingPlaneUsingExtent)

            // ヒット結果の中で一番カメラに近い平面
            if let result = planeHitTestResults.first {

                // 3Dコンテンツを生成、配置
                let meth = MeshResource.generateSphere(radius: 0.005)
                let color = UIColor.green
                let material = SimpleMaterial(color: color, isMetallic: false)
                let coloredSphere = ModelEntity(mesh: meth, materials: [material])

                let pointAnchor = AnchorEntity(world: result.worldTransform)
                pointAnchor.addChild(coloredSphere)

                // シーンに追加
                arView.scene.addAnchor(pointAnchor)

                if arView.scene.anchors.count == RulerInfo.pointNum {

                    // ３次元空間における２点間の距離を求める公式
                    // √(x1-x2)*(x1-x2)+(y1-y2)*(y1-y2)+(z1-z2)*(z1-z2)

                    let startAnchor = arView.scene.anchors[0]
                    let endAnchor = arView.scene.anchors[1]

                    // アンカー座標からワールド座標に変換
                    let startWorldPositon = startAnchor.convert(position: startAnchor.position, to: nil)
                    let endWorldPositon = endAnchor.convert(position: endAnchor.position, to: nil)

                    let x = startWorldPositon.x - endWorldPositon.x
                    let y = startWorldPositon.y - endWorldPositon.y
                    let z = startWorldPositon.z - endWorldPositon.z

                    let distance = sqrtf(x * x + y * y + z * z)

                    gameInfo.distance = distance
                }
            }
        }

    //MARK:- ARSessionDelegate

    // ARAnchorが追加されると呼ばれます
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {

        for anchor in anchors {

            if let anchorName = anchor.name, anchorName == EntityName.bulletAnchor {
                //                bulletShotCode(named: EntityName.bullet, for: anchor)
                bulletShotCode(named: EntityName.selfBullet, for: anchor)
            }

            else if let anchorName = anchor.name, anchorName.hasSuffix(UIDevice.current.name) == false {
                bulletShotCode(named: EntityName.enemyBullet, for: anchor)
            }

            // 対戦相手のアンカー
            if let participantAnchor = anchor as? ARParticipantAnchor {

                let anchorEntity = AnchorEntity(anchor: participantAnchor)

                let meth = MeshResource.generateSphere(radius: 0.03)
                let color = UIColor.green

                let material = SimpleMaterial(color: color, isMetallic: false)
                let coloredSphere = ModelEntity(mesh: meth, materials: [material])

                coloredSphere.components[CollisionComponent] = CollisionComponent(
                    shapes: [ShapeResource.generateBox(size: [0.1,0.1,0.1])]
                )
                coloredSphere.name = EntityName.multiHitBox
                anchorEntity.addChild(coloredSphere)

                arView.scene.addAnchor(anchorEntity)
            }
        }
    }
    // CollaborationData生成
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {

        guard let multiSession = multiSession else { return }

        if !multiSession.connectedPeers.isEmpty {

            // CollaborationDataを作成
            guard let encodeData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
            else { return }

            // CollaborationDataを送信
            let detailsCritical = data.priority == .critical
            sendData(encodeData, reliably: detailsCritical, peers: multiSession.connectedPeers)
        }
    }
}

extension float4x4 {

    init(translation vector: SIMD3<Float>) {
        self.init(.init(1, 0, 0, 0),
                  .init(0, 1, 0, 0),
                  .init(0, 0, 1, 0),
                  .init(vector.x, vector.y, vector.z, 1))
    }
}
