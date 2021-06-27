import UIKit
import RealityKit

class CameraBox {

    // 当たり判定
    var hitBox: (Entity & HasCollision)!

    // 名称
    var name: String = ""

    // 初期化
    init(entityName: String) {

        name = entityName
        hitBox = createHitBox()
    }

    // ヒットボックスの生成
    func createHitBox() -> (Entity & HasCollision) {

        // 立方体の大きさ
        let boxMesh = MeshResource.generateBox(size: 0.1)

        // 立方体を緑に設定して生成
        let boxMaterial = UnlitMaterial(color: UIColor.green)
        let boxModel = ModelEntity(mesh: boxMesh, materials: [boxMaterial])

        boxModel.name = name

        // 衝突コンポーネント
        boxModel.components[CollisionComponent] = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: [0.1,0.1,0.1])]
        )

        return boxModel
    }
}
