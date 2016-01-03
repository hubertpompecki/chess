require_relative "board.rb"
require_relative "piece.rb"
require_relative "pawn.rb"
require_relative "knight.rb"
require_relative "bishop.rb"
require_relative "rook.rb"
require_relative "queen.rb"
require_relative "king.rb"


module Chess

  class Game
    
    attr_reader :board, :current_player, :other_player
    
    def initialize(board, options = {})
      @board = board
      @castling_monitor = CastlingMonitor.new(board)
      initialize_players(options[:black_starts])
      set_up_board(options[:board_state])
    end
    
    def move(from, to)
      check_move_for_errors(from.upcase, to.upcase)
      move_piece(from, to)
      swap_players
    end
    
    def check_mate?
      if board.in_check?(board.white_king_location, :white)
        checked_colour = :white
        all_moves = board.get_all_moves(:white)
      elsif board.in_check?(board.black_king_location, :black)
        checked_colour = :black
        all_moves = board.get_all_moves(:black)
      else
        return false
      end
      
      if all_moves.any? { |move| saves_from_check?(move) }
        false
      else
        checked_colour
      end
    end
    
    private
    
      def initialize_players(black_starts)
        @current_player, @other_player = black_starts ? [:black, :white] : [:white, :black]
      end
      
      def set_up_board(board_state)
        board_state ? add_pieces_to_board(board_state) : default_set_up
      end
      
      def default_set_up
        # white pieces
        'A'.upto('H') { |col| board.place_piece(Pawn.new(:white), col + '2') }
        white_king = King.new(:white)
        right_white_rook = Rook.new(:white)
        left_white_rook = Rook.new(:white)
        board.place_piece(left_white_rook, "A1")
        board.place_piece(Knight.new(:white), "B1")
        board.place_piece(Bishop.new(:white), "C1")
        board.place_piece(Queen.new(:white), "D1")
        board.place_piece(white_king, "E1")
        board.place_piece(Bishop.new(:white), "F1")
        board.place_piece(Knight.new(:white), "G1")
        board.place_piece(right_white_rook, "H1")
        # black pieces
        'A'.upto('H') { |col| board.place_piece(Pawn.new(:black), col + '7') }
        black_king = King.new(:black)
        right_black_rook = Rook.new(:black)
        left_black_rook = Rook.new(:black)
        board.place_piece(left_black_rook, "A8")
        board.place_piece(Knight.new(:black), "B8")
        board.place_piece(Bishop.new(:black), "C8")
        board.place_piece(Queen.new(:black), "D8")
        board.place_piece(black_king, "E8")
        board.place_piece(Bishop.new(:black), "F8")
        board.place_piece(Knight.new(:black), "G8")
        board.place_piece(right_black_rook, "H8")
      end
      
      def add_pieces_to_board(board_state)
        board_state.each do |square, piece|
          piece_colour, piece_class = piece.split
          board.place_piece(find_class(piece_class).new(piece_colour.to_sym), square)
        end
      end
      
      def find_class(piece_class)
        module_name = self.class.name.split("::").first + "::"
        Object.const_get(module_name + piece_class)
      end
      
      def check_move_for_errors(from, to)
        # starting square is not empty
        raise InvalidMoveError unless piece = board.get_square(from)
        # can't move opponent's piece
        raise InvalidMoveError if piece.colour != current_player
        # target square has to be on board
        raise InvalidMoveError unless Board.valid_square?(to)
        # can only move within the piece's range
        raise InvalidMoveError unless piece.possible_moves(from, board.state).include?(to)
        # can't take own piece
        raise InvalidMoveError if board.get_square(to) && board.get_square(to).colour == current_player
        # can't leave own king in check
        raise InvalidMoveError if check_king_in_check(from, to)
        @castling_monitor.check_move(from, to)
      end
      
      def check_king_in_check(from, to)
        to_piece = board.get_square(to)
        
        # do the move
        move_piece(from, to)
        
        # check if king in check
        if current_player == :white
          in_check = board.white_king_location && board.in_check?(board.white_king_location, current_player)
        else
          in_check = board.black_king_location && board.in_check?(board.black_king_location, current_player)
        end
        
        # undo the move
        move_piece(to, from)
        board.place_piece(to_piece, to)
        
        in_check
      end
      
      def move_piece(from, to)
        piece = board.get_square(from)
        board.place_piece(nil, from)
        board.place_piece(piece, to)
      end
      
      def swap_players
        @current_player, @other_player = @other_player, @current_player
      end
      
      def saves_from_check?(move)
        from, to = move
        # temporarily swap players to investigate possible opponent's moves
        swap_players
        begin
          check_move_for_errors(from, to)
        rescue
          return false
        ensure
          swap_players
        end
        true
      end
      
    class InvalidMoveError < StandardError
    end
    
    class CastlingMonitor
      
      def initialize(board)
        @board = board
        @possible_castlings = {
          white_short: true,
          white_long: true,
          black_short: true,
          black_long: true
        }
      end
      
      def check_move(from, to)
        moving_piece = @board.get_square(from)
        if moving_piece.is_a?(King) && moving_piece.colour == :white && from == "E1" && to == "G1"
          white_short_castling
        elsif moving_piece.is_a?(King) && moving_piece.colour == :white && from == "E1" && to == "C1"
          white_long_castling
        elsif moving_piece.is_a?(King) && moving_piece.colour == :black && from == "E8" && to == "G8"
          black_short_castling
        elsif moving_piece.is_a?(King) && moving_piece.colour == :black && from == "E8" && to == "C8"
          black_long_castling
        else
          @possible_castlings[:white_short] = false if from == "E1" || from == "H1" || to == "H1"
          @possible_castlings[:white_long] = false if from == "E1" || from == "A1" || to == "A1"
          @possible_castlings[:black_short] = false if from == "E8" || from == "H8" || to == "H8"
          @possible_castlings[:black_long] = false if from == "E8" || from == "A8" || to == "A8"
        end
      end
      
      def white_short_castling_possible
        @possible_castlings[:white_short] &&
        !@board.in_check?("E1", :white) &&
        !@board.in_check?("F1", :white) &&
        !@board.in_check?("G1", :white) &&
        !@board.get_square("F1") &&
        !@board.get_square("G1")
      end
      
      def white_short_castling
        raise Game::InvalidMoveError unless white_short_castling_possible
        piece = @board.get_square("H1")
        @board.place_piece(nil, "H1")
        @board.place_piece(piece, "F1")
      end
      
      def white_long_castling_possible
        @possible_castlings[:white_long] &&
        !@board.in_check?("E1", :white) &&
        !@board.in_check?("D1", :white) &&
        !@board.in_check?("C1", :white) &&
        !@board.get_square("D1") &&
        !@board.get_square("C1")
      end
      
      def white_long_castling
        raise Game::InvalidMoveError unless white_long_castling_possible
        piece = @board.get_square("A1")
        @board.place_piece(nil, "A1")
        @board.place_piece(piece, "D1")
      end
      
      def black_short_castling_possible
        @possible_castlings[:black_short] &&
        !@board.in_check?("E8", :black) &&
        !@board.in_check?("F8", :black) &&
        !@board.in_check?("G8", :black) &&
        !@board.get_square("F8") &&
        !@board.get_square("G8")
      end
      
      def black_short_castling
        raise Game::InvalidMoveError unless black_short_castling_possible
        piece = @board.get_square("H8")
        @board.place_piece(nil, "H8")
        @board.place_piece(piece, "F8")
      end
      
      def black_long_castling_possible
        @possible_castlings[:black_long] &&
        !@board.in_check?("E8", :black) &&
        !@board.in_check?("D8", :black) &&
        !@board.in_check?("C8", :black) &&
        !@board.get_square("D8") &&
        !@board.get_square("C8")
      end
      
      def black_long_castling
        raise Game::InvalidMoveError unless black_long_castling_possible
        piece = @board.get_square("A8")
        @board.place_piece(nil, "A8")
        @board.place_piece(piece, "D8")
      end
    end
    
  end
  
end