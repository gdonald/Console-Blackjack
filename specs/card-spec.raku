use BDD::Behave;
use lib 'lib';
use Console::Blackjack::Card;

describe 'Console::Blackjack::Card', {
  describe 'construction', {
    it 'returns a Card from .new', {
      expect(Card.new(value => 0, suit => 0)).to.be-a(Card);
    }

    it 'stores the value', {
      expect(Card.new(value => 0, suit => 0).value).to.be(0);
    }
  }

  describe 'is-ace', {
    it 'is True for value 0', {
      expect(Card.new(value => 0, suit => 0).is-ace).to.be-truthy;
    }

    it 'is False for value 1', {
      expect(Card.new(value => 1, suit => 0).is-ace).to.be-falsy;
    }

    it 'is False for a Jack', {
      expect(Card.new(value => 9, suit => 0).is-ace).to.be-falsy;
    }
  }

  describe 'is-ten', {
    it 'is False for value 8 (a nine)', {
      expect(Card.new(value => 8, suit => 0).is-ten).to.be-falsy;
    }

    it 'is True for value 9 (a ten)', {
      expect(Card.new(value => 9, suit => 0).is-ten).to.be-truthy;
    }

    it 'is True for value 10 (Jack)', {
      expect(Card.new(value => 10, suit => 0).is-ten).to.be-truthy;
    }

    it 'is True for value 11 (Queen)', {
      expect(Card.new(value => 11, suit => 0).is-ten).to.be-truthy;
    }

    it 'is True for value 12 (King)', {
      expect(Card.new(value => 12, suit => 0).is-ten).to.be-truthy;
    }
  }

  describe 'faces tables', {
    it 'has 14 rows in faces (13 ranks + hidden)', {
      expect(Card.faces.elems).to.be(14);
    }

    it 'has 14 rows in faces2', {
      expect(Card.faces2.elems).to.be(14);
    }

    it 'has A♠ at faces[0][0]', {
      expect(Card.faces[0][0]).to.be('A♠');
    }

    it 'has K♦ at faces[12][3]', {
      expect(Card.faces[12][3]).to.be('K♦');
    }

    it 'has the hidden card at faces[13][0]', {
      expect(Card.faces[13][0]).to.be('??');
    }

    it 'has 🂡 at faces2[0][0]', {
      expect(Card.faces2[0][0]).to.be('🂡');
    }
  }

  describe 'draw with face-type 1', {
    before-each {
      Card.face-type = 1;
    }

    it 'returns A♠ for ace of spades', {
      expect(Card.new(value => 0, suit => 0).draw).to.be('A♠');
    }

    it 'returns K♦ for king of diamonds', {
      expect(Card.new(value => 12, suit => 3).draw).to.be('K♦');
    }
  }

  describe 'draw with face-type 2', {
    before-each {
      Card.face-type = 2;
    }

    after-each {
      Card.face-type = 1;
    }

    it 'returns unicode ace of spades', {
      expect(Card.new(value => 0, suit => 0).draw).to.be('🂡');
    }

    it 'returns unicode ten of hearts', {
      expect(Card.new(value => 9, suit => 1).draw).to.be('🂺');
    }
  }

  describe 'face-type class accessor', {
    after-each {
      Card.face-type = 1;
    }

    it 'is settable to 1', {
      Card.face-type = 1;
      expect(Card.face-type).to.be(1);
    }

    it 'is settable to 2', {
      Card.face-type = 2;
      expect(Card.face-type).to.be(2);
    }
  }
}
