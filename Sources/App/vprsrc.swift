import Vapor
import Leaf

struct ViperViewFiles: NIOLeafSource {
    
    /// root directory of the project
    let rootDirectory: String
    /// modules directory
    let modulesDirectory: String
    /// resources directory name
    let resourcesDirectory: String
    /// views folder name
    let viewsFolderName: String
    /// file extension
    let fileExtension: String
    /// fileio used to read files
    let fileio: NonBlockingFileIO

    /// file template function implementation
    func file(template: String, escape: Bool = false, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        let ext = "." + fileExtension
        let components = template.split(separator: "/")
        let pathComponents = [String(components.first!), viewsFolderName] + components.dropFirst().map { String($0) }
        let moduleFile = modulesDirectory + "/" + pathComponents.joined(separator: "/") + ext
        return read(path: rootDirectory + moduleFile, on: eventLoop)
    }
}

protocol NIOLeafSource: LeafSource {

    var fileio: NonBlockingFileIO { get }
    /// reads an existing file and returns a byte buffer future
    func read(path: String, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer>
}

extension NIOLeafSource {
    func read(path: String, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        fileio.openFile(path: path, eventLoop: eventLoop)
        .flatMapErrorThrowing { _ in throw LeafError(.noTemplateExists(path)) }
        .flatMap { handle, region in
            fileio.read(fileRegion: region, allocator: .init(), eventLoop: eventLoop)
            .flatMapThrowing { buffer in
                try handle.close()
                return buffer
            }
        }
    }
}

struct ViperBundledViewFiles: NIOLeafSource {

    let module: String
    /// root directory
    let rootDirectory: String
    /// file extension
    let fileExtension: String
    /// fileio used to read files
    let fileio: NonBlockingFileIO

    /// file template function implementation
    func file(template: String, escape: Bool = false, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        let name = template.split(separator: "/").first!.lowercased()
        let path = template.split(separator: "/").dropFirst().map { String($0) }.joined(separator: "/")
        let file = rootDirectory + path  + "." + fileExtension
        print(file)
//        print("---")
//        print(name)
//        print(template)
//        print(path)
//        print(file)
//        print("---")

        if module == name {
            return read(path: file, on: eventLoop)
        }
        return eventLoop.future(error: LeafError(.noTemplateExists(path)))
    }
}
