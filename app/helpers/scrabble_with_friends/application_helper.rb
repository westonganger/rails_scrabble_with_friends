module ScrabbleWithFriends
  module ApplicationHelper
    def board_square(row_index:, col_index:, letter:)
      cell = [row_index, col_index]

      additional_classes = []

      if ScrabbleWithFriends::Game::DOUBLE_LETTER_CELLS.include?(cell)
        additional_classes << "double-letter-square"
        content = "2X Letter"
      elsif ScrabbleWithFriends::Game::TRIPLE_LETTER_CELLS.include?(cell)
        additional_classes << "triple-letter-square"
        content = "3X Letter"
      elsif ScrabbleWithFriends::Game::DOUBLE_WORD_CELLS.include?(cell)
        additional_classes << "double-word-square"
        content = "2X Word"
      elsif ScrabbleWithFriends::Game::TRIPLE_WORD_CELLS.include?(cell)
        additional_classes << "triple-word-square"
        content = "3X Word"
      elsif cell == [7, 7]
        additional_classes << "center-square"
        content = "Center"
      end

      if letter.blank?
        additional_classes << "available"
      else
        content = tile(letter: letter)
      end

      content_tag(
        :div,
        content,
        class: "board-square #{additional_classes.join(" ")}",
        "data-row-index" => row_index,
        "data-col-index" => col_index,
      )
    end

    def tile(letter:, moveable: false)
      if letter
        points = ScrabbleWithFriends::Game::TILE_SCORES.fetch(letter)

        inner_html = <<~HTML
          <span class="tile-letter">#{letter}</span>
          <span class="tile-points">#{points}</span>
        HTML
      end

      content_tag(
        :span,
        inner_html&.html_safe,
        class: "tile #{'moveable' if moveable} #{'wildcard-letter' if letter == ScrabbleWithFriends::Game::WILDCARD}",
      )
    end
  end
end
