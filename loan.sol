// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC20Token {
function transfer(address, uint256) external returns (bool);
function approve(address, uint256) external returns (bool);

function transferFrom(
    address,
    address,
    uint256
) external returns (bool);

function totalSupply() external view returns (uint256);

function balanceOf(address) external view returns (uint256);

function allowance(address, address) external view returns (uint256);

event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
);
}

contract LoanManagementContract {
using SafeMath for uint256;
uint256 private loansCount = 0;
address private cUsdTokenAddress =
    0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

struct Loan {
    address borrower;
    address lender;
    uint256 principal;
    uint256 interestRate;
    uint256 dueDate;
    uint256 penaltyRate;
    bool isExtended;
    bool isRepaid;
}

mapping(uint256 => Loan) private loans;
mapping(uint256 => bool) private exists;

modifier exist(uint256 _index) {
    require(exists[_index], "Query of non-existent loan");
    _;
}

modifier onlyLoanParticipant(uint256 _index) {
    require(
        msg.sender == loans[_index].borrower ||
            msg.sender == loans[_index].lender,
        "Unauthorized participant"
    );
    _;
}

modifier onlyBorrower(uint256 _index) {
    require(
        msg.sender == loans[_index].borrower,
        "Only borrower can perform this operation"
    );
    _;
}

modifier onlyLender(uint256 _index) {
    require(
        msg.sender == loans[_index].lender,
        "Only lender can perform this operation"
    );
    _;
}

modifier notRepaid(uint256 _index) {
    require(!loans[_index].isRepaid, "Loan has already been repaid");
    _;
}

modifier notExtended(uint256 _index) {
    require(!loans[_index].isExtended, "Loan has already been extended");
    _;
}

function createLoan(
    address _lender,
    uint256 _principal,
    uint256 _interestRate,
    uint256 _dueDate,
    uint256 _penaltyRate
) external {
    require(_principal > 0, "Principal amount must be greater than zero");
    require(
        _interestRate > 0,
        "Interest rate must be greater than zero"
    );
    require(_dueDate > block.timestamp, "Invalid due date");

    loans[loansCount] = Loan(
        msg.sender,
        _lender,
        _principal,
        _interestRate,
        _dueDate,
        _penaltyRate,
        false,
        false
    );

    exists[loansCount] = true;
    loansCount++;
}

function repayLoan(uint256 _index)
    external
    payable
    exist(_index)
    onlyBorrower(_index)
    notRepaid(_index)
{
    Loan storage loan = loans[_index];

    uint256 repaymentAmount = loan.principal.add(
        calculateInterest(loan.principal, loan.interestRate)
    );

    require(
        msg.value >= repaymentAmount,
        "Insufficient funds to repay the loan"
    );

    loan.isRepaid = true;

    if (msg.value > repaymentAmount) {
         payable(msg.sender).transfer(msg.value.sub(repaymentAmount));

    }
}

function calculateInterest(uint256 _principal, uint256 _interestRate)
    private
    pure
    returns (uint256)
{
    return _principal.mul(_interestRate).div(100);
}

function getLoanDetails(uint256 _index)
    external
    view
    exist(_index)
    returns (
        address borrower,
        address lender,
        uint256 principal,
        uint256 interestRate,
        uint256 dueDate,
        uint256 penaltyRate,
        bool isExtended,
        bool isRepaid
    )
{
    Loan memory loan = loans[_index];
    borrower = loan.borrower;
    lender = loan.lender;
    principal = loan.principal;
    interestRate = loan.interestRate;
    dueDate = loan.dueDate;
    penaltyRate = loan.penaltyRate;
    isExtended = loan.isExtended;
    isRepaid = loan.isRepaid;
}

function extendLoan(uint256 _index)
    external
    exist(_index)
    onlyBorrower(_index)
    notExtended(_index)
{
    Loan storage loan = loans[_index];
    require(!loan.isRepaid, "Cannot extend a repaid loan");

    loan.isExtended = true;
    loan.dueDate = loan.dueDate.add(30 days);
}

function assessPenalty(uint256 _index)
    external
    exist(_index)
    onlyLoanParticipant(_index)
    notRepaid(_index)
{
    Loan storage loan = loans[_index];
    require(block.timestamp > loan.dueDate, "No penalty is due");

    uint256 penaltyAmount = calculateInterest(
        loan.principal,
        loan.penaltyRate
    );

    require(
        IERC20Token(cUsdTokenAddress).transferFrom(
            msg.sender,
            loan.lender,
            penaltyAmount
        ),
        "Transfer failed."
    );
}
}

