//
//  configure.swift
//  Feather
//
//  Created by Tibor Bodecs on 2019. 12. 17..
//

import FeatherCore
import LeafFoundation
/// drivers
import FluentSQLiteDriver
import LiquidLocalDriver
/// modules
//import SwiftyModule
//import MarkdownModule
//import RedirectModule
//import SponsorModule
//import StaticModule
//import BlogModule

public func configure(_ app: Application) throws {    
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    /*
    LeafFileMiddleware.defaultMediaType = .html
    LeafFileMiddleware.processableExtensions = ["leaf", "html", "css", "js"]
    LeafFileMiddleware[.css] = [
        "background": "green",
        "padding": "16px",
    ]
    LeafFileMiddleware.contexts = [
        .css: [
            "background": "#eee",
            "padding": "16px",
        ],
        .html: [
            "title": "Hello world!"
        ],
    ]


    if let lfm = LeafFileMiddleware(publicDirectory: app.directory.publicDirectory) {
        app.middleware.use(lfm)
    }
    */

    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    app.fileStorages.use(.local(publicUrl: Application.baseUrl,
                                publicPath: app.directory.publicDirectory,
                                workDirectory: "assets"), as: .local)

    app.routes.defaultMaxBodySize = "10mb"

    app.sessions.use(.fluent)
    app.migrations.add(SessionRecord.migration)
    app.middleware.use(SlashMiddleware())
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(LeafFoundationMiddleware())
    

    let modules: [ViperModule] = [
        UserBuilder(),
        SystemBuilder(),
        AdminBuilder(),
        ApiBuilder(),
        FrontendBuilder(),
        
        MenuBuilder(),
        RedirectBuilder(),
        SponsorBuilder(),
        StaticBuilder(),
        BlogBuilder(),
        SiteBuilder(),
        AnalyticsBuilder(),

        SwiftyBuilder(),
        MarkdownBuilder(),
    ].map { $0.build() }
    
    let defaultSource = NIOLeafFiles(fileio: app.fileio,
                               limits: [.requireExtensions],
                               sandboxDirectory: app.directory.resourcesDirectory,
                               viewDirectory: app.directory.viewsDirectory,
                               defaultExtension: "html")
    
    let featherCoreSource = FeatherCoreLeafSource(fileExtension: "html", fileio: app.fileio)
    
    let moduleSource = ViperLeafSource(workingDirectory: app.directory.workingDirectory,
                                       modulesLocation: "Sources/App/Modules",
                                       templatesDirectory: "Templates",
                                       fileExtension: "html",
                                       fileio: app.fileio)

    let multipleSources = LeafSources()
    try multipleSources.register(using: defaultSource)
    try multipleSources.register(source: "feather-core", using: featherCoreSource)
    try multipleSources.register(source: "local-modules", using: moduleSource)

//    for module in modules {
//        guard let url = module.bundleUrl else { continue }
//
//        let moduleSource = ViperBundledViewFiles(module: module.name,
//                                                 rootDirectory: url.path.withTrailingSlash,
//                                                 fileExtension: "html",
//                                                 fileio: app.fileio)
//
//        try multipleSources.register(source: "\(module.name)-module", using: moduleSource)
//    }

    LeafEngine.sources = multipleSources
    LeafEngine.useLeafFoundation()
    LeafEngine.entities.use(Resolve(), asMethod: "resolve")
    LeafEngine.entities.use(InlineSvg(), asFunction: "svg")
    LeafEngine.entities.use(Hook(), asFunction: "Hook")
    LeafEngine.entities.use(HookAll(), asFunction: "HookAll")
    LeafRenderer.Option.timeout = 1.000 //ms

    if app.isDebug {
        LeafRenderer.Option.caching = .bypass
    }
    app.views.use(.leaf)
    
    try app.viper.use(modules)

    app.middleware.use(FeatherCoreLeafExtensionMiddleware())
    app.middleware.use(LeafFeatherExtensionMiddleware())
    
    try app.autoMigrate().wait()
}
