import { Word, WordBook } from '../model/WordModel';

function w(id: string, word: string, phonetic: string, meaning: string,
  example: string, exampleCn: string): Word {
  const item: Word = {
    id: id,
    word: word,
    phonetic: phonetic,
    meaning: meaning,
    example: example,
    exampleCn: exampleCn
  };
  return item;
}

const CET4_WORDS: Word[] = [
  w('c4-1', 'abandon', '/əˈbændən/', 'v. 放弃，抛弃', 'He abandoned the plan at the last minute.', '他在最后一刻放弃了这个计划。'),
  w('c4-2', 'absolute', '/ˈæbsəluːt/', 'adj. 绝对的，完全的', 'You have absolute freedom here.', '在这里你有绝对的自由。'),
  w('c4-3', 'abundant', '/əˈbʌndənt/', 'adj. 丰富的，充裕的', 'The area is abundant in wildlife.', '这个地区野生动物资源丰富。'),
  w('c4-4', 'accurate', '/ˈækjərət/', 'adj. 精确的，准确的', 'The data is accurate and up to date.', '这些数据准确且是最新的。'),
  w('c4-5', 'adapt', '/əˈdæpt/', 'v. 适应，改编', 'She quickly adapted to the new environment.', '她很快适应了新环境。'),
  w('c4-6', 'adequate', '/ˈædɪkwət/', 'adj. 足够的，适当的', 'Make sure you get adequate sleep.', '确保你有充足的睡眠。'),
  w('c4-7', 'ambiguous', '/æmˈbɪɡjuəs/', 'adj. 模糊不清的，有歧义的', 'His answer was deliberately ambiguous.', '他的回答故意含糊其辞。'),
  w('c4-8', 'anticipate', '/ænˈtɪsɪpeɪt/', 'v. 预期，预料', 'We anticipate strong demand for the product.', '我们预计该产品需求旺盛。'),
  w('c4-9', 'apparent', '/əˈpærənt/', 'adj. 显然的，表面上的', 'It was apparent that she was tired.', '很明显她累了。'),
  w('c4-10', 'approach', '/əˈprəʊtʃ/', 'v. 接近 n. 方法', 'We need a new approach to the problem.', '我们需要解决问题的新方法。'),
  w('c4-11', 'appropriate', '/əˈprəʊpriət/', 'adj. 恰当的，合适的', 'Jeans are not appropriate for this occasion.', '牛仔裤不适合这个场合。'),
  w('c4-12', 'arbitrary', '/ˈɑːbɪtrəri/', 'adj. 任意的，武断的', 'The choice seems completely arbitrary.', '这个选择似乎完全是随意的。'),
  w('c4-13', 'assess', '/əˈses/', 'v. 评估，评定', 'Teachers assess each student’s progress.', '老师评估每个学生的进步。'),
  w('c4-14', 'attribute', '/əˈtrɪbjuːt/', 'v. 把…归因于', 'She attributes her success to hard work.', '她把成功归因于努力工作。'),
  w('c4-15', 'authentic', '/ɔːˈθentɪk/', 'adj. 真实的，正宗的', 'The restaurant serves authentic Sichuan food.', '这家餐厅供应正宗的川菜。'),
  w('c4-16', 'budget', '/ˈbʌdʒɪt/', 'n. 预算', 'We exceeded our travel budget.', '我们超出了旅行预算。'),
  w('c4-17', 'capable', '/ˈkeɪpəbl/', 'adj. 有能力的', 'She is capable of handling the job alone.', '她有能力独自处理这项工作。'),
  w('c4-18', 'circumstance', '/ˈsɜːkəmstəns/', 'n. 情况，环境', 'Under no circumstances should you give up.', '在任何情况下你都不应放弃。'),
  w('c4-19', 'coincide', '/ˌkəʊɪnˈsaɪd/', 'v. 同时发生；一致', 'My views coincide with hers.', '我的观点和她的一致。'),
  w('c4-20', 'comprehensive', '/ˌkɒmprɪˈhensɪv/', 'adj. 全面的，综合的', 'The report gives a comprehensive overview.', '这份报告给出了全面的概述。'),
  w('c4-21', 'conceive', '/kənˈsiːv/', 'v. 构想，设想', 'He conceived the idea during a trip.', '他在一次旅行中构想出了这个主意。'),
  w('c4-22', 'condemn', '/kənˈdem/', 'v. 谴责，指责', 'The court condemned the attack.', '法院谴责了这次袭击。'),
  w('c4-23', 'confirm', '/kənˈfɜːm/', 'v. 确认，证实', 'Please confirm your reservation by email.', '请通过电子邮件确认您的预订。'),
  w('c4-24', 'consequence', '/ˈkɒnsɪkwəns/', 'n. 后果，结果', 'Every choice has its consequences.', '每个选择都有其后果。'),
  w('c4-25', 'considerable', '/kənˈsɪdərəbl/', 'adj. 相当大的，可观的', 'The project requires considerable effort.', '该项目需要相当大的努力。'),
  w('c4-26', 'contradict', '/ˌkɒntrəˈdɪkt/', 'v. 反驳，与…矛盾', 'The two reports contradict each other.', '这两份报告相互矛盾。'),
  w('c4-27', 'conventional', '/kənˈvenʃənl/', 'adj. 传统的，常规的', 'He rejected conventional teaching methods.', '他拒绝了传统的教学方法。'),
  w('c4-28', 'crucial', '/ˈkruːʃl/', 'adj. 至关重要的', 'Timing is crucial to our success.', '时机对我们的成功至关重要。'),
  w('c4-29', 'deteriorate', '/dɪˈtɪəriəreɪt/', 'v. 恶化，变坏', 'His health deteriorated rapidly.', '他的健康迅速恶化。'),
  w('c4-30', 'dilemma', '/dɪˈlemə/', 'n. 困境，进退两难', 'She faced the dilemma of loyalty versus duty.', '她面临忠诚与职责的两难困境。'),
  w('c4-31', 'diminish', '/dɪˈmɪnɪʃ/', 'v. 减少，削弱', 'Time will not diminish our friendship.', '时间不会削弱我们的友谊。'),
  w('c4-32', 'distinct', '/dɪˈstɪŋkt/', 'adj. 明显的，独特的', 'The two species are quite distinct.', '这两个物种截然不同。'),
  w('c4-33', 'distribute', '/dɪˈstrɪbjuːt/', 'v. 分发，分配', 'They distribute food to the homeless.', '他们向无家可归者分发食物。'),
  w('c4-34', 'elaborate', '/ɪˈlæbərət/', 'adj. 精心制作的 v. 详述', 'Could you elaborate on your proposal?', '你能详细说明你的提议吗？'),
  w('c4-35', 'eliminate', '/ɪˈlɪmɪneɪt/', 'v. 消除，淘汰', 'We aim to eliminate wasted time.', '我们的目标是消除时间的浪费。'),
  w('c4-36', 'emphasize', '/ˈemfəsaɪz/', 'v. 强调', 'The teacher emphasized the key points.', '老师强调了重点。'),
  w('c4-37', 'enormous', '/ɪˈnɔːməs/', 'adj. 巨大的，庞大的', 'The task requires enormous patience.', '这项任务需要极大的耐心。'),
  w('c4-38', 'essential', '/ɪˈsenʃl/', 'adj. 必不可少的', 'Water is essential for all life.', '水对所有生命都是必不可少的。'),
  w('c4-39', 'evaluate', '/ɪˈvæljueɪt/', 'v. 评价，估计', 'We will evaluate the results next week.', '我们下周评估结果。'),
  w('c4-40', 'exaggerate', '/ɪɡˈzædʒəreɪt/', 'v. 夸大，夸张', 'Don’t exaggerate the risks involved.', '不要夸大其中涉及的风险。'),
  w('c4-41', 'facilitate', '/fəˈsɪlɪteɪt/', 'v. 促进，使便利', 'The new system facilitates communication.', '新系统促进了沟通。'),
  w('c4-42', 'fundamental', '/ˌfʌndəˈmentl/', 'adj. 基本的，根本的', 'There is a fundamental difference between them.', '他们之间有根本的区别。'),
  w('c4-43', 'generate', '/ˈdʒenəreɪt/', 'v. 产生，引起', 'Wind turbines generate electricity.', '风力涡轮机发电。'),
  w('c4-44', 'identical', '/aɪˈdentɪkl/', 'adj. 完全相同的', 'The two paintings are almost identical.', '这两幅画几乎一模一样。'),
  w('c4-45', 'inevitable', '/ɪnˈevɪtəbl/', 'adj. 不可避免的', 'Change is inevitable in any industry.', '任何行业的变化都是不可避免的。'),
  w('c4-46', 'influence', '/ˈɪnfluəns/', 'n./v. 影响', 'Parents have a strong influence on children.', '父母对孩子有很大的影响。'),
  w('c4-47', 'initiative', '/ɪˈnɪʃətɪv/', 'n. 倡议；主动性', 'She took the initiative to organize the event.', '她主动组织了这次活动。'),
  w('c4-48', 'innovative', '/ˈɪnəveɪtɪv/', 'adj. 创新的', 'The company is known for innovative design.', '这家公司以创新设计闻名。'),
  w('c4-49', 'interfere', '/ˌɪntəˈfɪə/', 'v. 干涉，妨碍', 'Don’t interfere with his work.', '不要妨碍他的工作。'),
  w('c4-50', 'justify', '/ˈdʒʌstɪfaɪ/', 'v. 证明…正当', 'How can you justify such a high price?', '你怎么能为这么高的价格辩护？'),
  w('c4-51', 'moderate', '/ˈmɒdərət/', 'adj. 适度的，温和的', 'Moderate exercise is good for health.', '适度运动有益健康。'),
  w('c4-52', 'negotiate', '/nɪˈɡəʊʃieɪt/', 'v. 谈判，协商', 'The two sides agreed to negotiate.', '双方同意进行谈判。'),
  w('c4-53', 'objective', '/əbˈdʒektɪv/', 'n. 目标 adj. 客观的', 'Our objective is to cut costs by 10%.', '我们的目标是将成本降低 10%。'),
  w('c4-54', 'obstacle', '/ˈɒbstəkl/', 'n. 障碍，阻碍', 'Fear is often the biggest obstacle.', '恐惧往往是最大的障碍。'),
  w('c4-55', 'overwhelming', '/ˌəʊvəˈwelmɪŋ/', 'adj. 压倒性的', 'The response was overwhelmingly positive.', '反响非常积极。'),
  w('c4-56', 'perspective', '/pəˈspektɪv/', 'n. 观点，视角', 'Try to see it from her perspective.', '试着从她的角度看问题。'),
  w('c4-57', 'phenomenon', '/fəˈnɒmɪnən/', 'n. 现象', 'Lightning is a natural phenomenon.', '闪电是一种自然现象。'),
  w('c4-58', 'priority', '/praɪˈɒrəti/', 'n. 优先事项', 'Health should be your top priority.', '健康应该是你的头等大事。'),
  w('c4-59', 'reluctant', '/rɪˈlʌktənt/', 'adj. 不情愿的', 'He was reluctant to admit his mistake.', '他不愿承认自己的错误。'),
  w('c4-60', 'significant', '/sɪɡˈnɪfɪkənt/', 'adj. 重要的，显著的', 'There was a significant improvement in sales.', '销售额有显著提升。'),
];

const CET6_WORDS: Word[] = [
  w('c6-1', 'adverse', '/ˈædvɜːs/', 'adj. 不利的，有害的', 'The drug has no adverse effects.', '这种药物没有不良反应。'),
  w('c6-2', 'advocate', '/ˈædvəkeɪt/', 'v. 提倡 n. 拥护者', 'She advocates a balanced diet.', '她提倡均衡饮食。'),
  w('c6-3', 'alleviate', '/əˈliːvieɪt/', 'v. 减轻，缓解', 'The medicine alleviates the pain.', '这种药可以缓解疼痛。'),
  w('c6-4', 'ambitious', '/æmˈbɪʃəs/', 'adj. 有雄心的', 'He has an ambitious plan for the future.', '他对未来有一个雄心勃勃的计划。'),
  w('c6-5', 'arouse', '/əˈraʊz/', 'v. 唤起，激发', 'The speech aroused public concern.', '演讲引起了公众的关注。'),
  w('c6-6', 'assimilate', '/əˈsɪməleɪt/', 'v. 吸收，同化', 'Children assimilate new ideas quickly.', '孩子很快吸收新思想。'),
  w('c6-7', 'cognitive', '/ˈkɒɡnətɪv/', 'adj. 认知的', 'Reading improves cognitive ability.', '阅读能提高认知能力。'),
  w('c6-8', 'compensate', '/ˈkɒmpenseɪt/', 'v. 补偿，弥补', 'Nothing can compensate for lost time.', '什么都无法弥补失去的时间。'),
  w('c6-9', 'comply', '/kəmˈplaɪ/', 'v. 遵守，服从', 'All firms must comply with the regulations.', '所有公司都必须遵守规定。'),
  w('c6-10', 'constrain', '/kənˈstreɪn/', 'v. 限制，约束', 'Lack of funding constrains our research.', '资金不足限制了我们的研究。'),
  w('c6-11', 'contemplate', '/ˈkɒntəmpleɪt/', 'v. 沉思，考虑', 'She contemplated changing her career.', '她考虑过换工作。'),
  w('c6-12', 'contrive', '/kənˈtraɪv/', 'v. 设法做到；设计', 'They contrived to meet despite the storm.', '尽管有暴风雨，他们还是设法见面了。'),
  w('c6-13', 'credibility', '/ˌkredəˈbɪləti/', 'n. 可信性，信誉', 'The scandal damaged his credibility.', '丑闻损害了他的信誉。'),
  w('c6-14', 'degrade', '/dɪˈɡreɪd/', 'v. 降低，使降级', 'Pollution degrades the environment.', '污染使环境退化。'),
  w('c6-15', 'deliberate', '/dɪˈlɪbərət/', 'adj. 故意的 v. 深思', 'It was a deliberate attempt to mislead.', '这是一个故意的误导。'),
  w('c6-16', 'denote', '/dɪˈnəʊt/', 'v. 表示，意味着', 'A red light denotes danger.', '红灯表示危险。'),
  w('c6-17', 'deprive', '/dɪˈpraɪv/', 'v. 剥夺', 'No one can deprive you of your rights.', '没有人能剥夺你的权利。'),
  w('c6-18', 'designate', '/ˈdezɪɡneɪt/', 'v. 指定，指派', 'The area was designated a nature reserve.', '该地区被指定为自然保护区。'),
  w('c6-19', 'deterioration', '/dɪˌtɪəriəˈreɪʃn/', 'n. 恶化', 'There has been a deterioration in air quality.', '空气质量一直在恶化。'),
  w('c6-20', 'discern', '/dɪˈsɜːn/', 'v. 辨别，察觉', 'It is hard to discern the truth.', '很难辨别真相。'),
  w('c6-21', 'discrepancy', '/dɪsˈkrepənsi/', 'n. 差异，不符', 'There is a discrepancy between the two accounts.', '两个账户之间存在差异。'),
  w('c6-22', 'elicit', '/ɪˈlɪsɪt/', 'v. 引出，诱出', 'The question elicited a heated debate.', '这个问题引发了激烈的辩论。'),
  w('c6-23', 'embark', '/ɪmˈbɑːk/', 'v. 着手，从事', 'He embarked on a new career.', '他开始了新的职业生涯。'),
  w('c6-24', 'embody', '/ɪmˈbɒdi/', 'v. 体现，包含', 'The design embodies simplicity and elegance.', '这个设计体现了简约与优雅。'),
  w('c6-25', 'entail', '/ɪnˈteɪl/', 'v. 需要，牵涉', 'The job entails a lot of travel.', '这份工作需要经常出差。'),
  w('c6-26', 'evoke', '/ɪˈvəʊk/', 'v. 唤起，引起', 'The song evokes memories of my childhood.', '这首歌唤起了我童年的回忆。'),
  w('c6-27', 'expenditure', '/ɪkˈspendɪtʃə/', 'n. 支出，花费', 'We must cut unnecessary expenditure.', '我们必须削减不必要的开支。'),
  w('c6-28', 'feasible', '/ˈfiːzəbl/', 'adj. 可行的', 'Is the plan financially feasible?', '这个计划在财务上可行吗？'),
  w('c6-29', 'formulate', '/ˈfɔːmjuleɪt/', 'v. 制定，系统地阐述', 'They formulated a new strategy.', '他们制定了新战略。'),
  w('c6-30', 'hinder', '/ˈhɪndə/', 'v. 阻碍，妨碍', 'Bad weather hindered the rescue effort.', '恶劣的天气阻碍了救援工作。'),
  w('c6-31', 'implicit', '/ɪmˈplɪsɪt/', 'adj. 含蓄的，暗含的', 'There was implicit criticism in his words.', '他的话中暗含批评。'),
  w('c6-32', 'incentive', '/ɪnˈsentɪv/', 'n. 激励，动机', 'Bonuses are an incentive to work harder.', '奖金是更努力工作的激励。'),
  w('c6-33', 'indispensable', '/ˌɪndɪˈspensəbl/', 'adj. 不可缺少的', 'She is indispensable to the team.', '她对团队来说是不可缺少的。'),
  w('c6-34', 'inherent', '/ɪnˈhɪərənt/', 'adj. 固有的，内在的', 'Risk is inherent in every investment.', '风险是每项投资固有的。'),
  w('c6-35', 'intact', '/ɪnˈtækt/', 'adj. 完好无损的', 'The ancient wall remains intact.', '古城墙依然完好无损。'),
  w('c6-36', 'mitigate', '/ˈmɪtɪɡeɪt/', 'v. 减轻，缓和', 'Trees help mitigate air pollution.', '树木有助于减轻空气污染。'),
  w('c6-37', 'notorious', '/nəʊˈtɔːriəs/', 'adj. 臭名昭著的', 'The area is notorious for traffic jams.', '这个地区因交通拥堵而臭名昭著。'),
  w('c6-38', 'prevail', '/prɪˈveɪl/', 'v. 盛行；获胜', 'Justice will prevail in the end.', '正义终将获胜。'),
  w('c6-39', 'profound', '/prəˈfaʊnd/', 'adj. 深刻的，深远的', 'The book had a profound impact on me.', '这本书对我有深远的影响。'),
  w('c6-40', 'scrutiny', '/ˈskruːtəni/', 'n. 仔细审查', 'The plan is under public scrutiny.', '该计划正受到公众的审视。'),
];

function makeBook(id: string, name: string, subtitle: string, words: Word[]): WordBook {
  const book: WordBook = {
    id: id,
    name: name,
    subtitle: subtitle,
    icon: '',
    words: words
  };
  return book;
}

export const BOOKS: WordBook[] = [
  makeBook('cet4', '四级核心词', 'CET-4 · 60 词精选', CET4_WORDS),
  makeBook('cet6', '六级核心词', 'CET-6 · 40 词精选', CET6_WORDS),
];

export function getBook(bookId: string): WordBook {
  for (const b of BOOKS) {
    if (b.id === bookId) {
      return b;
    }
  }
  return BOOKS[0];
}

// 按单词 ID 查找单词，找不到返回 undefined
export function findWord(wordId: string): Word | undefined {
  for (let b = 0; b < BOOKS.length; b++) {
    const book = BOOKS[b];
    for (let w = 0; w < book.words.length; w++) {
      if (book.words[w].id === wordId) {
        return book.words[w];
      }
    }
  }
  return undefined;
}
