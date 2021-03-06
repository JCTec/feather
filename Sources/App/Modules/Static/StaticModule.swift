//
//  StaticModule.swift
//  Feather
//
//  Created by Tibor Bödecs on 2020. 06. 07..
//

import Vapor
import Fluent
import ViperKit
import ViewKit
import FeatherCore

final class StaticModule: ViperModule {

    static var name: String = "static"

    var router: ViperRouter? { StaticRouter() }

    func boot(_ app: Application) throws {
        app.databases.middleware.use(MetadataMiddleware<StaticPageModel>())
    }

    var migrations: [Migration] {
        [
            StaticPageMigration_v1_0_0(),
        ]
    }

    var viewsUrl: URL? {
        nil
//        Bundle.module.bundleURL
//            .appendingPathComponent("Contents")
//            .appendingPathComponent("Resources")
//            .appendingPathComponent("Views")
    }

    // MARK: - hook functions

    func invoke(name: String, req: Request, params: [String : Any] = [:]) -> EventLoopFuture<Any?>? {
        switch name {
        case "frontend-page":
            return frontendPageHook(req: req)
        default:
            return nil
        }
    }
    
    func invokeSync(name: String, req: Request?, params: [String : Any]) -> Any? {
        switch name {
        case "installer":
            return StaticInstaller()
        case "leaf-admin-menu":
            return [
                "name": "Static",
                "icon": "file-text",
                "items": LeafData.array([
                    [
                        "url": "/admin/static/pages/",
                        "label": "Pages",
                    ],
                ])
            ]
        default:
            return nil
        }
    }

    private func frontendPageHook(req: Request) -> EventLoopFuture<Any?>? {
        StaticPageModel.findMetadata(on: req.db, path: req.url.path)
        .filter(Metadata.self, \.$status != .archived)
        .first()
        .flatMap { page -> EventLoopFuture<Response?> in
            guard let page = page, let metadata = try? page.joined(Metadata.self) else {
                return req.eventLoop.future(nil)
            }

            /// if the page is implemented as a Swift page handler, the page-content hook will take care of the rest.
            if page.content.hasPrefix("["), page.content.hasSuffix("]") {
                let name = String(page.content.dropFirst().dropLast())
                return req.hook(name, type: Response.self, params: ["page-metadata": metadata])
            }

            let filteredContent = metadata.filter(page.content, req: req)

            return req.leaf.render(template: "Static/Frontend/Page", context: [
                "page": [
                    "id": LeafData.string(page.id?.uuidString),
                    "title": LeafData.string(page.title),
                    "content": LeafData.string(filteredContent),
                ],
                "metadata": metadata.leafData,
            ])
            .encodeResponse(for: req).map { $0 as Response? }
        }
        .map { $0 as Any }
    }

}
