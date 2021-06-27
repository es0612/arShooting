import UIKit
import RealityKit

class BulletStar {

    // 弾丸
    var bullet: (Entity & HasCollision)!

    // 名称
    var name: String = ""

    // 初期化
    init(startPosition:SIMD3<Float>, entityName: String) {

        name = entityName

        bullet = createBullet()
        bullet.position = startPosition

    }

    // 弾丸の生成
    func createBullet() -> (Entity & HasCollision) {

        // 球体の半径(m)
        var redius: Float = 0.1

        // 色
        var color: UIColor = UIColor.white

        // 自分自身の弾丸
        if name == EntityName.selfBullet {
            redius = 0.1
            color = UIColor.blue
        }
        // 敵の弾丸
        else if name == EntityName.enemyBullet {
            redius = 0.01
            color = UIColor.red
        }

        // 球体を生成
        let sphereMesh = MeshResource.generateSphere(radius: redius)

        // 球体の色や質感を設定
        let sphereMaterial = SimpleMaterial(color: color, roughness: 0.0, isMetallic: false)

        // 3Dコンテンツを生成
        let sphereModel = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])

        sphereModel.name = name

        // 衝突コンポーネント
        sphereModel.components[CollisionComponent] = CollisionComponent(
            shapes: [ShapeResource.generateSphere(radius: 0.1)]
        )

        return sphereModel
    }
}
