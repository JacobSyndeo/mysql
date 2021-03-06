import Async
import Bits
import Foundation

/// A statement that has been bound and is ready for execution
public final class BoundStatement {
    /// The statement to bind to
    let statement: PreparedStatement

    /// The amount of bound parameters
    var boundParameters = 0

    /// The internal cache used to build up the header and null map of the query
    var header: [UInt8] = [
        0x17, // Header
        0,0,0,0, // statementId
        0, // flags
        1, 0, 0, 0 // iteration count (always 1)
    ]

    // Stores the bound parameters
    var parameterData = [UInt8]()

    /// Creates a new BoundStatemnt
    init(forStatement statement: PreparedStatement) {
        self.statement = statement

        header.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.advanced(by: 1).withMemoryRebound(to: UInt32.self, capacity: 1) { pointer in
                pointer.pointee = statement.statementID
            }
        }

        for _ in 0..<(statement.parameters.count + 7)/8 {
            header.append(0)
        }

        // Types are sent to the server
        header.append(1)
    }

    /// https://mariadb.com/kb/en/library/com_stmt_execute/
    ///
    /// Executes the bound statement
    ///
    /// TODO: Support cursors
    ///
    /// Flags:
    ///     0    no cursor
    ///     1    read only
    ///     2    cursor for update
    ///     4    scrollable cursor
    func execute(into stream: AnyInputStream<Row>) throws {
        guard boundParameters == statement.parameters.count else {
            throw MySQLError(.notEnoughParametersBound, source: .capture())
        }
        
        let pushStream = PushStream<Row>()
        pushStream.output(to: stream)
        
        let packet = Packet(data: header + parameterData)
        
        let parseResults = ParseResults(stream: pushStream, context: self.statement.stateMachine)
        let task = ExecutePreparation(packet: packet, parse: parseResults)
        
        statement.stateMachine.execute(task)
    }

    /// Fetched `count` more results from MySQL
    func getMore(count: UInt32, output: AnyInputStream<Row>) {
        let task = GetMore(id: self.statement.statementID, amount: count, output: output)
        statement.stateMachine.execute(task)
    }
}
