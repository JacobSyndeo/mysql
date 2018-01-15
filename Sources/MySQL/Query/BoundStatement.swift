import Async
import Bits
import Foundation

///// A statement that has been bound and is ready for execution
//public final class BoundStatement {
//    /// The statement to bind to
//    let statement: PreparedStatement
//
//    /// The amount of bound parameters
//    var boundParameters = 0
//
//    /// The internal cache used to build up the header and null map of the query
//    var header = Data([
//        0x17, // Header
//        0,0,0,0, // statementId
//        0, // flags
//        1, 0, 0, 0 // iteration count (always 1)
//    ])
//
//    // Stores the bound parameters
//    var parameterData = Data()
//
//    /// Creates a new BoundStatemnt
//    init(forStatement statement: PreparedStatement) {
//        self.statement = statement
//
//        header.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
//            pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
//                pointer.pointee = statement.statementID
//            }
//        }
//
//        for _ in 0..<(statement.parameterCount + 7)/8 {
//            header.append(0)
//        }
//
//        // Types are sent to the server
//        header.append(1)
//    }
//
//    /// https://mariadb.com/kb/en/library/com_stmt_execute/
//    ///
//    /// Executes the bound statement
//    ///
//    /// TODO: Support cursors
//    ///
//    /// Flags:
//    ///     0    no cursor
//    ///     1    read only
//    ///     2    cursor for update
//    ///     4    scrollable cursor
//    func send() throws {
//        guard boundParameters == statement.parameterCount else {
//            throw MySQLError(.notEnoughParametersBound)
//        }
//
//        statement.connection.serializer.next(Packet(data: header + parameterData))
//    }
//
//    /// Fetched `count` more results from MySQL
//    func getMore(count: UInt32) throws {
//        var data = Data(repeating: 0x1c, count: 9)
//
//        data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
//            pointer.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 2) { pointer in
//                pointer[0] = self.statement.statementID
//                pointer[1] = count
//            }
//        }
//
//        statement.connection.serializer.next(Packet(data: data))
//    }
//
//    /// Executes the bound statement and returns all decoded results in a future array
//    public func all<D: Decodable>(_ type: D.Type) -> Future<[D]> {
//        var results = [D]()
//        return self.forEach(D.self) { res in
//            results.append(res)
//        }.map(to: [D].self) {
//            return results
//        }
//    }
//
//    public func execute() throws -> Future<Void> {
//        let promise = Promise<Void>()
//
//        // Set up a parser
//        statement.connection.parser.drain { packet, _ in
//            if let (affectedRows, lastInsertID) = try packet.parseBinaryOK() {
//                self.statement.connection.affectedRows = affectedRows
//                self.statement.connection.lastInsertID = lastInsertID
//            }
//
//            promise.complete()
//        }.catch { err in
//            promise.fail(err)
//        }.upstream?.request()
//
//        // Send the query
//        try send()
//
//        return promise.future
//    }
//
//    /// A simple callback closure
//    public typealias Callback<T> = (T) throws -> ()
//
//    /// Loops over all rows resulting from the query
//    ///
//    /// - parameter query: Fetches results using this query
//    /// - parameter handler: Executes the handler for each `Row`
//    /// - throws: Network error
//    /// - returns: A future that will be completed when all results have been processed by the handler
//    @discardableResult
//    internal func forEachRow(_ handler: @escaping Callback<Row>) -> Future<Void> {
//        do {
//            try send()
//        } catch {
//            return Future(error: error)
//        }
//
//        // On successful send
//        let promise = Promise(Void.self)
//
//        let rowStream = RowStream(mysql41: true, binary: true) { affectedRows, lastInsertID in
//            self.statement.connection.affectedRows = affectedRows
//            self.statement.connection.lastInsertID = lastInsertID
//        }
//
//        self.statement.connection.parser.stream(to: rowStream).drain { row, connection in
//            try handler(row)
//            rowStream.request()
//        }.catch { error in
//            promise.fail(error)
//        }.finally {
//            rowStream.cancel()
//            promise.complete()
//        }.upstream?.request()
//
//        rowStream.onEOF = { flags in
//            try self.getMore(count: UInt32.max)
//        }
//
//        return promise.future
//    }
//
//    public func stream<D, Stream>(_ type: D.Type, in query: MySQLQuery, to stream: Stream) throws
//        where D: Decodable, Stream: Async.InputStream, Stream.Input == D
//    {
//        let rowStream = RowStream(mysql41: true, binary: true) { affectedRows, lastInsertID in
//            self.statement.connection.affectedRows = affectedRows
//            self.statement.connection.lastInsertID = lastInsertID
//        }
//
//        self.statement.connection.parser.stream(to: rowStream).map(to: D.self) { row in
//            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
//            return try D(from: decoder)
//        }.output(to: stream)
//
//        // Send the query
//        try send()
//    }
//
//    /// Loops over all rows resulting from the query
//    ///
//    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
//    /// - parameter query: Fetches results using this query
//    /// - parameter handler: Executes the handler for each deserialized result of type `D`
//    /// - throws: Network error
//    /// - returns: A future that will be completed when all results have been processed by the handler
//    @discardableResult
//    public func forEach<D>(_ type: D.Type, _ handler: @escaping Callback<D>) -> Future<Void>
//        where D: Decodable
//    {
//        return forEachRow { row in
//            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
//            try handler(D(from: decoder))
//        }
//    }
//}
//