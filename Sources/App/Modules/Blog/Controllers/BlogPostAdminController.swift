//
//  BlogPostAdminController.swift
//  Feather
//
//  Created by Tibor Bodecs on 2020. 03. 23..
//

import Fluent
import FeatherCore

struct BlogPostAdminController: ViperAdminViewController {
    typealias Module = BlogModule
    typealias Model = BlogPostModel
    typealias EditForm = BlogPostEditForm
    
    // MARK: - api
    
    var listSortable: [FieldKey] {
        [
            Model.FieldKeys.imageKey,
            Model.FieldKeys.title,
        ]
    }

    var listOrder: String { "desc" }
    
    func search(using qb: QueryBuilder<Model>, for searchTerm: String) {
        qb.filter(\.$title ~~ searchTerm)
        //qb.filter(\.$imageKey ~~ searchTerm)
    }
    
    private func path(_ model: Model) -> String {
        Model.path + model.id!.uuidString + ".jpg"
    }

    func beforeRender(req: Request, form: EditForm) -> EventLoopFuture<Void> {
        var future: EventLoopFuture<Void> = req.eventLoop.future()
        if let id = form.id, let uuid = UUID(uuidString: id) {
            future = findMetadata(on: req.db, uuid: uuid).map { form.metadata = $0 }
        }

        return req.eventLoop.flatten([
            BlogCategoryModel.query(on: req.db).all().mapEach(\.formFieldStringOption).map { form.categoryId.options = $0 },
            BlogAuthorModel.query(on: req.db).all().mapEach(\.formFieldStringOption).map { form.authorId.options = $0 },
            future,
        ])
    }
 
    func beforeCreate(req: Request, model: Model, form: EditForm) -> EventLoopFuture<Model> {
        model.id = UUID()
        var future: EventLoopFuture<Model> = req.eventLoop.future(model)
        if let data = form.image.data {
            let key = path(model)
            future = req.fs.upload(key: key, data: data).map { url in
                //form.image.value = url
                model.imageKey = key
                return model
            }
        }
        return future
    }

//    func afterCreate(req: Request, form: EditForm, model: Model) -> EventLoopFuture<Response> {
//        req.redirect(to: req.url.path.replaceLastPath(model.viewIdentifier))
//    }
    
    func beforeUpdate(req: Request, model: Model, form: EditForm) -> EventLoopFuture<Model> {
        let key = path(model)
        var future: EventLoopFuture<Model> = req.eventLoop.future(model)
        if
            (form.image.delete || form.image.data != nil),
            FileManager.default.fileExists(atPath: req.fs.resolve(key: key))
        {
            future = req.fs.delete(key: key).map { model }
        }
        if let data = form.image.data {
            return future.flatMap { model in
                return req.fs.upload(key: key, data: data).map { url in
                    //form.image.value = url
                    model.imageKey = key
                    return model
                }
            }
        }
        return future
    }

    func beforeDelete(req: Request, model: Model) -> EventLoopFuture<Model> {
        req.fs.delete(key: path(model)).map { model }
    }
    
    

}
